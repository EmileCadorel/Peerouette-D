import std.stdio;
import netez = netez._;
import screenshot.takeshot, screenshot.buffer, std.conv;
import deamon.protocol;
import std.concurrency, std.datetime;
import core.thread : Thread;

immutable long __FRAME_TIME__ = cast (long) ((1.0f / __FPS__) * 1000);

immutable int __WIDTH__ = 1920;
immutable int __HEIGHT__ = 1080;

class Session : netez.ServSession!Protocol {

    private netez.Address _addr;
    private netez.Socket _sock;
    
    this (netez.Socket sock) {
	super (sock);
	this._sock = sock;
    }

    override void onBegin (netez.Address addr) {
	this._addr = addr;
	writeln ("New stream on ", addr);
	Buffer.register (thisTid);
	sendingStream ();
    }

    void sendingStream () {
	auto begin = Clock.currTime ();
	bool fst = false;
	netez.Stream stream = null;
	while (this._sock.isAlive ()) {
	    auto loop = Clock.currTime ();	    
	    //writeln ("Loop each : ", loop - begin);
	    receive (
		(shared (ubyte)[] msg) {
		    if (stream is null) {
			this.proto.frame (__WIDTH__, __HEIGHT__, __WIDTH__ * __HEIGHT__);
			stream = this.proto.frame.open ();
		    }

		    auto beginSend = Clock.currTime;
		    stream.write (beginSend.toISOString ());
		    stream.write (cast (byte[]) msg);
		}
	    );
	    begin = Clock.currTime ();
	}
	
	super.endSession ();
    }
    
    override void onEnd () {
	Buffer.unregister (thisTid);
	//writeln ("Connexion out : ", this._addr);
    }
    
}

void launchScreenThread () {
    spawn (
    	() {
	    while (true) {
		auto begin = Clock.currTime ();
		Buffer.update ();
		auto end = Clock.currTime ();
		auto nbMs = (end - begin).total!"msecs";
		writeln ("Took : ", end - begin, " cdc : ", __FRAME_TIME__);
		if (nbMs < __FRAME_TIME__) {
		    Thread.sleep (dur!"msecs" (__FRAME_TIME__ - nbMs));		    
		}
	    }
    	}
    );
}

void main (string [] args) {
    Buffer.init (__WIDTH__, __HEIGHT__);
    launchScreenThread ();
    auto serv = new netez.Server!Session (args);    
}
