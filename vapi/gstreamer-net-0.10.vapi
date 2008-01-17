/* gstreamer-net-0.10.vapi generated by lt-vapigen, do not modify. */

[CCode (cprefix = "Gst", lower_case_cprefix = "gst_")]
namespace Gst {
	[CCode (cheader_filename = "gst/gst.h")]
	public class NetTimePacket {
		public weak Gst.ClockTime local_time;
		public weak Gst.ClockTime remote_time;
		public NetTimePacket (uchar buffer);
		public static weak Gst.NetTimePacket receive (int fd, pointer addr, uint32 len);
		public int send (int fd, pointer addr, uint32 len);
		public uchar serialize ();
	}
	[CCode (cheader_filename = "gst/gst.h")]
	public class NetClientClock : Gst.SystemClock {
		public int sock;
		public weak int[] control_sock;
		public weak Gst.ClockTime current_timeout;
		public pointer servaddr;
		public weak GLib.Thread thread;
		public NetClientClock (string name, string remote_address, int remote_port, Gst.ClockTime base_time);
		[NoAccessorMethod]
		public weak string address { get; set; }
		[NoAccessorMethod]
		public weak int port { get; set; }
	}
	[CCode (cheader_filename = "gst/gst.h")]
	public class NetTimeProvider : Gst.Object {
		public int sock;
		public weak int[] control_sock;
		public weak GLib.Thread thread;
		public NetTimeProvider (Gst.Clock clock, string address, int port);
		[NoAccessorMethod]
		public weak bool active { get; set; }
		[NoAccessorMethod]
		public weak string address { get; set; }
		[NoAccessorMethod]
		public weak Gst.Clock clock { get; set; }
		[NoAccessorMethod]
		public weak int port { get; set; }
	}
	public const int NET_TIME_PACKET_SIZE;
}
