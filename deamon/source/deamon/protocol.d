module deamon.protocol;

import netez = netez._;


class Protocol : netez.Proto {

    netez.StreamMessage!(1, int, int, ulong) frame;
    
    this (netez.Socket sock) {
	super (sock);
	this.frame = new netez.StreamMessage!(1, int, int, ulong) (this);
    }
    
}
