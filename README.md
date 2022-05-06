# red5pro-watch-party-installer

## Overview

This installer script is a modified version of the [Red5 Pro Installer](https://github.com/red5pro/red5pro-installer) that will install the following on an Ubuntu 20.04 server:

1. Red5 Pro server (either the latest from downloads, a shared zipped distribution via a URL, or a locally copied zipped distribution)
2. A Let's Encrypt SSL certificate (valid for 90 days)
3. A WebRTC TURN server (see [this doc](https://www.red5pro.com/docs/installation/turn-stun/turnstun/) for more details)
4. The [node.js conference host backend](https://github.com/red5pro/red5pro-conference-host)
5. And the [Red5 Pro Watch Party example](https://github.com/red5pro/red5pro-watch-party)

## Usage

`./r5watchinstall.sh domain-url`

for example: `./r5watchinstall.sh red5test.red5.com`

## Prerequisites

You must have a valid Red5 Pro license key to run the server. If you want to install the latest, you will need your [red5pro.com](https://www.red5pro.com) account credentials.

In addition, you will need to create an A Record (with the IP address of your server) for the domain name which you intend to use for the server.

The watch-party example is a multi-user experience, and as such should be run on an instance with at least 4 CPUs and 8GB of memory.

## Instructions

Launch the installer script (`./r5watchinstall.sh mydomain.domain.com`) and select choice 1 - BASIC. Choose `INSTALL LATEST RED5PRO`. See [this readme](https://github.com/red5pro/red5pro-installer#basic-mode) for more details about the Red5 Pro server installer.

After the server has been installed, say **Yes** to configuring the red5pro service.

Next, choose to install an SSL Cert.

After installing the SSL cert, choose `X` to exit the server install piece. The script will automatically move on to install the other WatchParty elements.

## Testing the Watch Party

This example uses a stream called `demo-stream` for the main feed. This can be broadcast to the server via an RTMP source to `rtmp://mydomain.domain.com/live/demo-stream`, or through any other broadcast method.

Once that stream is live, connect to your server with a browser via `https://mydomain.domain.com/red5pro-watch-party/`. After giving your browser access to your camera and microphone, you can modify the stream name (or use the randomly-generated default) and click on **Join!** You will then enter the room along with any other participants who join the same room (red5pro is the default room for this example).



