/*
 * sanders-gnss-netstate: tell the Qualcomm GNSS HAL whether a data network
 * is up, as Android's framework does with IAGnssRil::updateNetworkState_2_0.
 * Without it the location stack believes there is no network: xtra-daemon
 * never downloads assistance (XTRA) data or NTP time, and the first GPS fix
 * takes many minutes.
 *
 * Usage: sanders-gnss-netstate <connected 0|1> <capabilities>
 *   capabilities: NOT_METERED (1) | NOT_ROAMING (2); the HAL treats a
 *   not-metered network as Wi-Fi and anything else as mobile data.
 *
 * Build: gcc -O2 -o sanders-gnss-netstate sanders-gnss-netstate.c \
 *            $(pkg-config --cflags --libs libgbinder libglibutil glib-2.0)
 */
#include <gbinder.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define GNSS_IFACE      "android.hardware.gnss@2.0::IGnss"
#define GNSS_FQNAME     GNSS_IFACE "/default"
#define AGNSS_RIL_IFACE "android.hardware.gnss@2.0::IAGnssRil"

/* Transaction codes: method order in IGnss.hal 1.0 (18), 1.1 (5), 2.0 */
#define IGNSS_GET_EXTENSION_AGNSS_RIL_2_0       28
/* IAGnssRil.hal 1.0 has 5 methods; updateNetworkState_2_0 is 2.0's first */
#define IAGNSS_RIL_UPDATE_NETWORK_STATE_2_0     6

/* android.hardware.gnss@2.0::IAGnssRil::NetworkAttributes */
typedef struct network_attributes {
    guint64 network_handle;     /* net_handle_t; 0 = default network */
    guint8 is_connected;
    guint8 pad1;
    guint16 capabilities;
    guint32 pad2;
    GBinderHidlString apn;
} NetworkAttributes;

G_STATIC_ASSERT(sizeof(NetworkAttributes) == 32);

static const GBinderWriterField network_attributes_f[] = {
    GBINDER_WRITER_FIELD_HIDL_STRING(NetworkAttributes, apn),
    GBINDER_WRITER_FIELD_END()
};

static const GBinderWriterType network_attributes_t = {
    GBINDER_WRITER_STRUCT_NAME_AND_SIZE(NetworkAttributes),
    network_attributes_f
};

static GBinderRemoteObject*
get_agnss_ril(GBinderServiceManager* sm, GBinderClient** gnss_client)
{
    int status = 0;
    GBinderRemoteObject* gnss = gbinder_servicemanager_get_service_sync(sm,
        GNSS_FQNAME, &status);
    GBinderRemoteReply* reply;
    GBinderReader reader;
    GBinderRemoteObject* ril = NULL;
    gint32 hidl_status;

    if (!gnss) {
        fprintf(stderr, "%s not available (%d)\n", GNSS_FQNAME, status);
        return NULL;
    }

    *gnss_client = gbinder_client_new(gnss, GNSS_IFACE);
    reply = gbinder_client_transact_sync_reply(*gnss_client,
        IGNSS_GET_EXTENSION_AGNSS_RIL_2_0, NULL, &status);
    if (reply) {
        gbinder_remote_reply_init_reader(reply, &reader);
        if (gbinder_reader_read_int32(&reader, &hidl_status) &&
            hidl_status == 0) {
            ril = gbinder_reader_read_object(&reader);
        }
        gbinder_remote_reply_unref(reply);
    }
    if (!ril) {
        fprintf(stderr, "getExtensionAGnssRil_2_0 failed (%d)\n", status);
    }
    return ril;
}

int main(int argc, char* argv[])
{
    GBinderServiceManager* sm;
    GBinderClient* gnss_client = NULL;
    GBinderRemoteObject* ril;
    NetworkAttributes attrs;
    int ret = 1;

    if (argc != 3) {
        fprintf(stderr, "usage: %s <connected 0|1> <capabilities>\n", argv[0]);
        return 2;
    }

    memset(&attrs, 0, sizeof(attrs));
    attrs.is_connected = atoi(argv[1]) ? 1 : 0;
    attrs.capabilities = (guint16) atoi(argv[2]);
    attrs.apn.data.str = "";
    attrs.apn.len = 0;

    sm = gbinder_servicemanager_new("/dev/hwbinder");
    if (!sm) {
        fprintf(stderr, "no hwbinder service manager\n");
        return 1;
    }

    ril = get_agnss_ril(sm, &gnss_client);
    if (ril) {
        GBinderClient* client = gbinder_client_new(ril, AGNSS_RIL_IFACE);
        GBinderLocalRequest* req = gbinder_client_new_request(client);
        GBinderRemoteReply* reply;
        GBinderWriter writer;
        GBinderReader reader;
        gint32 hidl_status = -1;
        gboolean success = FALSE;
        int status = 0;

        gbinder_local_request_init_writer(req, &writer);
        gbinder_writer_append_struct(&writer, &attrs, &network_attributes_t,
            NULL);
        reply = gbinder_client_transact_sync_reply(client,
            IAGNSS_RIL_UPDATE_NETWORK_STATE_2_0, req, &status);
        if (reply) {
            gbinder_remote_reply_init_reader(reply, &reader);
            if (gbinder_reader_read_int32(&reader, &hidl_status) &&
                hidl_status == 0) {
                gbinder_reader_read_bool(&reader, &success);
            }
            gbinder_remote_reply_unref(reply);
        }
        printf("updateNetworkState_2_0(connected=%u, caps=0x%x): %s\n",
            attrs.is_connected, attrs.capabilities,
            success ? "ok" : "failed");
        ret = success ? 0 : 1;

        gbinder_local_request_unref(req);
        gbinder_client_unref(client);
        gbinder_remote_object_unref(ril);
    }

    gbinder_client_unref(gnss_client);
    gbinder_servicemanager_unref(sm);
    return ret;
}
