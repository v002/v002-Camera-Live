v002 Camera Live
================

Important
---------

**v002 Camera Live has multiple issues on macOS Mojave and later. It is still available for download but we cannot provide support. We would welcome any developer work to get it going again.**

Introduction
------------

v002 Camera Live provides a Syphon server for a connected camera, allowing it to be used as a live video feed.

Currently the only supported cameras are Canon DSLRs, see [CAMERAS.md](https://github.com/v002/v002-Camera-Live/blob/master/CAMERAS.md) for a list.

You can download the app from the [releases page](https://github.com/v002/v002-Camera-Live/releases).

Typical latency of a Canon 7D is 120 ms (between 3 and 4 frames at 30 FPS), which is comparable to the latency of the same camera's HDMI output connected to a capture device.

Troubleshooting
---------------

- Connect your camera via USB, not HDMI. HDMI capture requires an HDMI capture device.
- If your camera model was released after the latest build of Camera Live, it probably isn't supported yet.
- Make sure your camera's firmware is up to date. Firmware updates are available from Canon in your region. 
- Quit Canon's EOS Utility if you have it open.
- If your camera has a Wi-Fi/NFC mode, disable it before using Camera Live.
- The camera sends the image used for Live View - the dimensions will not match the camera's movie recording settings.

Changes
-------

See [the change log](https://github.com/v002/v002-Camera-Live/blob/master/CHANGES.md) for details of changes between released builds.

Building From Source
--------------------

To build the project yourself, you must acquire your own copies of the necessary libraries:

 - The Canon EDSDK is available from Canon in your region. Place the Framework and Header folders from the SDK in the EDSDK folder alongside this file.
 - libjpeg-turbo is available from http://libjpeg-turbo.virtualgl.org. Install using the libjpeg-turbo installer.
 - Syphon is available from http://syphon.v002.info. Place Syphon.framework in the Syphon folder alongside this file.
