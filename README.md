# Peerouette-D
Data streaming (pas peer-to-peer, va falloir m'expliquer le nom)

# Prerequisite

- [dub](https://code.dlang.org/download)
- SDL2
  - libsdl2-dev
- ffmpeg-dev 
  -  libavcodec
  -  libavformat
  -  libavutil
  -  libavfilter
  -  libavdevice
  -  libswscale
  -  libswresample

- [Deimos libX11 binding](https://github.com/D-Programming-Deimos/libX11)
- [netez-d](https://github.com/EmileCadorel/netez-d)

```bash
cd ~/.dub/packages
git clone https://github.com/EmileCadorel/netez-d.git
```

# Installation 

```bash
$ cd deamon 
$ dub build
$ dub add-local .
$ cd ../display
$ dub build
```

# Launch
On the server side (with IP : 192.168.1.11)

```bash
$ ./peer-deamon 4040
```

On the client side : 
```bash
$ ./peer-display 192.168.1.11 4040
```

