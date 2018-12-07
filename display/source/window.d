module window;
import gfm.math, gfm.sdl2, gfm.opengl;
import std.stdio, std.algorithm;


class Window {

    private SDL2 _sdl2;
    private int _width, _height;
    private SDL2Window _window;
    private SDL2Renderer _render;
    private SDL2Texture _texture;
    private ubyte [] data;
    private string _title;
    private int _pitch;
    
    this (string title, int width, int height) {
	this._title = title;
	this.initWindow (width, height);
    }

    private void initWindow (int width, int height) {
	this._sdl2 = new SDL2 (null);
	this._sdl2.subSystemInit (SDL_INIT_VIDEO);

	this._width = width;
	this._height = height;

	const windowFlags = SDL_WINDOW_SHOWN |
	    SDL_WINDOW_INPUT_FOCUS |
	    SDL_WINDOW_MOUSE_FOCUS |
	    SDL_WINDOW_RESIZABLE;

	this._window = new SDL2Window (this._sdl2,
				       SDL_WINDOWPOS_UNDEFINED,
				       SDL_WINDOWPOS_UNDEFINED,
				       this._width,
				       this._height,
				       windowFlags);
       
	this._window.setTitle (this._title);
	this._render = new SDL2Renderer (this._window);

    }

    void render () {
	this._render.clear ();
	this._render.copy (this._texture, 0, 0);
	this._render.present ();
    }

    void initTexture (ubyte [] data) {
	auto surf = SDL_CreateRGBSurface(0, this._width, this._height, 32, 0, 0, 0, 0);
	
	this._pitch = surf.pitch;	
	this._texture = new SDL2Texture (this._render, new SDL2Surface (this._sdl2, surf, SDL2Surface.Owned.NO));
    }    

    
    void updateTexture (ubyte [] data) {
	this._texture.updateTexture (data.ptr, this._pitch);
    }    
    
}
