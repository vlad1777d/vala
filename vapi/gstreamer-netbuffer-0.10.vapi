/* gstreamer-netbuffer-0.10.vapi generated by lt-vapigen, do not modify. */

[CCode (cprefix = "Gst", lower_case_cprefix = "gst_")]
namespace Gst {
	[CCode (cprefix = "GST_NET_TYPE_", cheader_filename = "gst/gst.h")]
	public enum NetType {
		UNKNOWN,
		IP4,
		IP6,
	}
	[CCode (cheader_filename = "gst/gst.h")]
	public class NetAddress {
		public Gst.NetType type;
		public pointer address;
		public ushort port;
		public weak pointer[] _gst_reserved;
		[CCode (cname = "gst_netaddress_get_ip4_address")]
		public bool get_ip4_address (uint address, ushort port);
		[NoArrayLength]
		[CCode (cname = "gst_netaddress_get_ip6_address")]
		public bool get_ip6_address (uchar[] address, ushort port);
		[CCode (cname = "gst_netaddress_get_net_type")]
		public Gst.NetType get_net_type ();
		[CCode (cname = "gst_netaddress_set_ip4_address")]
		public void set_ip4_address (uint address, ushort port);
		[NoArrayLength]
		[CCode (cname = "gst_netaddress_set_ip6_address")]
		public void set_ip6_address (uchar[] address, ushort port);
	}
	[CCode (cheader_filename = "gst/gst.h")]
	public class NetBuffer {
		public weak Gst.Buffer buffer;
		public weak Gst.NetAddress from;
		public weak Gst.NetAddress to;
		public weak pointer[] _gst_reserved;
		[CCode (cname = "gst_netbuffer_new")]
		public NetBuffer ();
	}
	[CCode (cheader_filename = "gst/gst.h")]
	public class NetBufferClass {
		public weak Gst.BufferClass buffer_class;
		public weak pointer[] _gst_reserved;
	}
}
