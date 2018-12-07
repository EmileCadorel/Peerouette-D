import std.stdio;
import deamon.protocol, std.datetime;
import netez = netez._;
import window, std.stdio;
import screenshot.buffer;

class Session : netez.ClientSession!Protocol {

    this (netez.Socket sock) {
	super (sock);
	this.proto.frame.onRecv (&this.onFrame);
    }

    override void onBegin () {}

    void onFrame (netez.Stream stream, int width, int height, ulong size) {
	Buffer.init (width, height, false);
	
	auto window = new Window ("Truc", width, height);
	auto data = new ubyte[size * 4];
	auto frameBuffer = new ubyte [size * 4];
	window.initTexture (data);
	
	auto begin = Clock.currTime ();
	while (stream.isAlive ()) {
	    auto len = *(cast (ulong*) stream.rawRead (ulong.sizeof).ptr);	    
	    stream.rawRead (data [0 .. len]);

	    Buffer.addFrame (data [0 .. len]);
	    
	    auto begin_decode = Clock.currTime ();
	    if (Buffer.ffmpeg_decoder_decode_frame (data [0 .. len], frameBuffer.ptr)) {
		auto end_decode = Clock.currTime ();
		writeln ("Decoding took : ", end_decode - begin_decode);
	    	window.updateTexture (frameBuffer);
	    	window.render ();
	    }
	    
	    
	    auto end = Clock.currTime ();
	    writeln ("Frame : ", end - begin, " size : ", len);
	    begin = Clock.currTime ();
	}
	
	Buffer.flush ();    
	stream.close ();	
	super.endSession ();
    }

    override void onEnd () {
	writeln ("Closed !!");
    }
    
    
}

void main (string [] args) {
    auto client = new netez.Client!Session (args);
}
