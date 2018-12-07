module screenshot.takeshot;
import gfm.opengl, gfm.sdl2, std.file, std.stdio;
import utils.singleton, std.stdio;
import deimos.X11.X, deimos.X11.Xlib, deimos.X11.Xutil;
import deimos.X11.Xlib, deimos.X11.Xutil;
import std.datetime, std.conv;
import core.sys.posix.sys.shm;

alias ScreenShot = ScreenShotS.instance; 

struct XShmSegmentInfo {
    ulong shmseg;	/* resource id */
    int shmid;		/* kernel id */
    char *shmaddr;	/* address in client */
    int readOnly;	/* how the server should attach it */
}

extern (C) int XShmGetImage (
    Display*		/* dpy */,
    Drawable		/* d */,
    XImage*		/* image */,
    int			/* x */,
    int			/* y */,
    ulong	/* plane_mask */
);

extern (C) XImage *XShmCreateImage(
    Display*		/* dpy */,
    Visual*		/* visual */,
    uint	/* depth */,
    int			/* format */,
    char*		/* data */,
    XShmSegmentInfo*	/* shminfo */,
    uint	/* width */,
    uint	/* height */
);

extern (C) int XShmAttach(
    Display*		/* dpy */,
    XShmSegmentInfo*	/* shminfo */
);


class ScreenShotS {

    mixin Singleton;

    private SDL2 _sdl2;

    Display * display = null;
    Window win;
    XWindowAttributes attrib;

    XShmSegmentInfo shminfo;
    XImage * img = null;
    int _width, _height;
    
    this () {}
    
    void init (int width, int height) {	 
	writeln ("ici");
	display = XOpenDisplay(null);
	win     = XDefaultRootWindow(display);
	XGetWindowAttributes(display, win, &attrib);

	
	auto screen = attrib.screen;
	img = XShmCreateImage (display,
			       XDefaultVisualOfScreen (screen),
			       XDefaultDepthOfScreen (screen),
			       ZPixmap,
			       null, 
			       &shminfo,
			       width,
			       height
	);

	shminfo.shmid = shmget (IPC_PRIVATE, img.chars_per_line * img.height, IPC_CREAT | octal!777);
	shminfo.shmaddr = img.data = cast (char*) shmat (shminfo.shmid, null, 0);
	shminfo.readOnly = 0;
	assert (shminfo.shmid >= 0);

	int s1 = XShmAttach (display, &shminfo);
	writefln ("XShmAttach () %d\n", s1 != 0);
	
	this._width = width;
	this._height = height;
    }
    
    ubyte [] takeShot () {	
	auto begin = Clock.currTime ();
	XShmGetImage (display, win, img, 0, 0, 0x00ffffff);

	auto capt = Clock.currTime ();

	
	auto w = this._width - attrib.x;
	auto h = this._height - attrib.y;

	return (cast (ubyte*) img.data) [0 .. h * w * 4];
    }

    void saveTo (string filename) {				
	auto begin = Clock.currTime ();
	img = XGetSubImage (display, win, attrib.x, attrib.y, attrib.width, attrib.height, 0x00ffffff, ZPixmap,
		      img, 0, 0);
		      
	auto capt = Clock.currTime ();
	
	auto w = attrib.width - attrib.x;
	auto h = attrib.height - attrib.y;

	auto surf = SDL_CreateRGBSurface(0, w, h, img.bits_per_pixel, 0, 0, 0, 0);
	SDL_LockSurface(surf);
	auto created = Clock.currTime ();


	surf.pixels = img.data;
	auto loop = Clock.currTime ();

	SDL_UnlockSurface(surf);
	SDL_SaveBMP (surf, filename.ptr);
	
	auto end = Clock.currTime ();
	writeln ("Capt : ", capt - begin);
	writeln ("Create : ", created - capt);
	writeln ("Loop : ", loop - created);
	writeln ("Free : ", end - loop);
	writeln ("All : ", end - begin);	
    }
    
}
