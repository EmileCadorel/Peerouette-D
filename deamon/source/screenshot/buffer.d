module screenshot.buffer;

import screenshot.takeshot;
import core.thread : Thread;
import std.concurrency;
import utils.singleton, std.container;
import std.stdio;
import std.datetime;

alias Buffer = BufferS.instance;

import ffmpeg.libavformat.avformat;
import ffmpeg.libavcodec.avcodec;
import ffmpeg.libavutil.avutil;
import ffmpeg.libavutil.mem;
import ffmpeg.libavutil.frame;
import ffmpeg.libavfilter.avfilter;
import ffmpeg.libavformat.avformat_version;
import ffmpeg.libavcodec.avcodec_version;
import ffmpeg.libavutil.avutil_version;
import ffmpeg.libavfilter.avfilter_version;
import ffmpeg.libswscale.swscale;
import ffmpeg.libswscale.swscale_version;
import ffmpeg.libswresample.swresample;
import ffmpeg.libswresample.swresample_version;

import ffmpeg.libavcodec.avcodec;
import ffmpeg.libavformat.avformat;
import ffmpeg.libavformat.avio;
import ffmpeg.libavutil.avutil;

@nogc nothrow extern(C) {
    int av_image_alloc(ubyte **pointers, int *linesizes, int w, int h, AVPixelFormat pix_fmt, int );
    int avcodec_encode_video (AVCodecContext * avctx, ubyte *	buf, int buf_size,  AVFrame * pict); 			
}

public immutable int __FPS__ = 50;
immutable float __SCALING__ = 1;

class BufferS {

    mixin Singleton;

    private shared (ubyte[]) _datas = null;

    private SList!Tid _streams;

    private AVCodec* codec;
    private AVCodecContext * c = null;
    private ulong size;
    private ubyte[] framebuffer;
    private File file;
    private SwsContext* sws_context;
    private AVFrame * frame;
    private AVFrame * picture;
    private AVPacket *packt;
    private AVCodecParserContext *parser;
   
    this () {
	this.file = File ("out.h264", "wb");
    }

    void init (int width, int height, bool willEncode = true) {
	avcodec_register_all();
	if (willEncode) {
	    ScreenShot.init (width, height);
	    codec = avcodec_find_encoder(AVCodecID.AV_CODEC_ID_MPEG2VIDEO);            // finding the H264 encoder
	    assert (codec !is null, "Codec not found\n");

	    this.c = avcodec_alloc_context3 (codec);
	    this.c.bit_rate = (cast (int) (width * __SCALING__)) * (cast (int) (height * __SCALING__));
	    this.c.width = cast (int) (width * __SCALING__);
	    this.c.height = cast (int) (height * __SCALING__);

	    c.time_base.num = 1;
	    c.time_base.den = __FPS__;
	    c.global_quality = 31;
	    c.pix_fmt = AVPixelFormat.AV_PIX_FMT_YUV420P;                           // universal pixel format for video enco
	    

	    printFields (c);
	    if (avcodec_open2 (c, codec, null) < 0)
		assert (false, "could not open codec");

	    this.frame = av_frame_alloc ();
	    this.frame.format = c.pix_fmt;
	    this.frame.width = c.width;
	    this.frame.height = c.height;		       
	
	    if (av_image_alloc (frame.data.ptr, frame.linesize.ptr, c.width, c.height, c.pix_fmt, 32) < 0)
		assert (false, "Could not allocate raw picture buffer");	
	    
	} else {
	    codec = avcodec_find_decoder(AVCodecID.AV_CODEC_ID_MPEG2VIDEO);            // finding the H264 encoder
	    assert (codec !is null, "deCodec not found\n");

	    this.parser = av_parser_init (codec.id);
	    
	    this.c = avcodec_alloc_context3 (codec);	    
	    this.c.bit_rate = (cast (int) (width * __SCALING__)) * (cast (int) (height * __SCALING__));
	    this.c.width = cast (int) (width * __SCALING__);
	    this.c.height = cast (int) (height * __SCALING__);
	    this.c.time_base.num = 1;
	    this.c.time_base.den = __FPS__;
	    this.c.pix_fmt = AVPixelFormat.AV_PIX_FMT_YUV420P;                           // universal pixel format for video encoding

	    if (avcodec_open2 (this.c, codec, null) < 0)
		assert (false, "could not open codec");

	    this.frame = av_frame_alloc ();
	    this.frame.format = c.pix_fmt;
	    this.frame.width = c.width;
	    this.frame.height = c.height;
	    
	    this.packt = av_packet_alloc ();	    
	}
       		

	
    }
	    
    void ffmpeg_encoder_set_frame_yuv_from_rgb (AVFrame* fr, ubyte* rgb) {	
	int [1] linesizes = [4 * cast (int) (c.width / __SCALING__)];
	sws_context = sws_getCachedContext(sws_context,
					   cast (int) (c.width / __SCALING__), cast (int) (c.height / __SCALING__), AVPixelFormat.AV_PIX_FMT_BGR0,
					   c.width, c.height, AVPixelFormat.AV_PIX_FMT_YUV420P,
					   0, null, null, null);
	
	sws_scale (sws_context, &rgb, linesizes.ptr, 0, cast (int) (c.height / __SCALING__), fr.data.ptr, fr.linesize.ptr);
    }
    
    void ffmpeg_decoder_set_frame_rgb_from_yuv (AVFrame* fr, ubyte* rgb32) {
	int [1] linesizes = [4 * cast (int) (c.width / __SCALING__)];
	sws_context = sws_getCachedContext(sws_context,
					   c.width, c.height, AVPixelFormat.AV_PIX_FMT_YUV420P,
					   cast (int) (c.width / __SCALING__), cast (int) (c.height / __SCALING__), AVPixelFormat.AV_PIX_FMT_BGR0,
					   0, null, null, null);

	sws_scale (sws_context, fr.data.ptr, fr.linesize.ptr, 0, c.height, &rgb32, linesizes.ptr);
    }
    
    ubyte[] ffmpeg_encoder_encode_frame (ubyte* rgb) {
	int ret, got_out;
	ffmpeg_encoder_set_frame_yuv_from_rgb (this.frame, rgb);

	AVPacket packt;
	av_init_packet (&packt);
	packt.data = null;
	packt.size = 0;	
	ret = avcodec_encode_video2(c, &packt, this.frame, &got_out);
	
	if (got_out != 0) {
	    auto data = packt.data [0 .. packt.size].dup ();
	    av_packet_unref (&packt);
	    return data;
	}
	
	return [];
    }

    void printFields(T)(T args)
    {
	import std.conv;
	auto values = args.tupleof;
    
	size_t max;
	size_t temp;
	foreach (index, value; values)
	    {
		temp = T.tupleof[index].stringof.length;
		if (max < temp) max = temp;
	    }
	max += 1;
	foreach (index, value; values)
	    {
		writefln("%-" ~ to!string(max) ~ "s %s", T.tupleof[index].stringof, value);
	    }                
    }
    
    bool decodeNextFrame (AVCodecContext *dec_ctx, AVFrame *frame, AVPacket *pkt) {
	char [1024] buf;
	int ret;

	ret = avcodec_send_packet(dec_ctx, pkt);
	if (ret < 0) {
	    writeln ("Error sending a packet for decoding");	
	}
		
	ret = avcodec_receive_frame(dec_ctx, frame);
	if (ret == -11 || ret == AVERROR_EOF)
	    return false;
	else if (ret < 0) {
	    writeln ("Error during decoding\n");
	    return false;
	}
	
	//writeln (frame.data [0][0 .. frame.height * frame.linesize [0]]);
	return true; //frame.data [0][0 .. frame.height * frame.linesize [0]];       
    }


    bool ffmpeg_decoder_decode_frame (ubyte[] data, ubyte* rgb32) {
    	int ret, got_out = 1;

	while (data.length > 0) {
            ret = av_parser_parse2(parser, c, &this.packt.data, &this.packt.size,
                                   data.ptr, cast (int) data.length, AV_NOPTS_VALUE, AV_NOPTS_VALUE, 0);
	    
            if (ret < 0) {
		writeln ("Error while parsing\n");
		return false;
            }
	    
            data = data [ret .. $];	    
            if (this.packt.size != 0) {
		decodeNextFrame (c, this.frame, this.packt);		
	    }
        }
	ffmpeg_decoder_set_frame_rgb_from_yuv (frame, rgb32);
    	return true;
    }
    
    void update () {
	static int i = 0;
	auto begin_shoot = Clock.currTime ();	
	auto buf = ScreenShot.takeShot ().ptr;
	//this._datas = cast (shared) buf;
	frame.pts = i;
	i++;
	
	auto begin_encode = Clock.currTime ();	
	this._datas = cast (shared) ffmpeg_encoder_encode_frame (buf);
	auto end_encode = Clock.currTime ();

	writeln ("Shot : ", begin_encode - begin_shoot, " encode : ", end_encode - begin_encode);
	
	informStreams ();
    }

    void addFrame (ubyte [] data) {
	file.rawWrite (data);
    }
    
    void flush () {
	auto out_size = 1;
	int got_out = 1;

	avcodec_close (this.c);
	av_free (c);
	av_freep (frame.data.ptr);
	av_frame_free (&frame);
    }
    
    shared (ubyte []) getDatas () {
	return this._datas;
    }

    void informStreams () {
	foreach (it ; this._streams) {
	    send (it, this._datas);
	}
    }

    void register (Tid tid) {
	this._streams.insert (tid);
	writeln ("New thread listener : ", tid);
    }

    void unregister (Tid tid) {
	this._streams.linearRemoveElement (tid);
    }
    
}
