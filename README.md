v002 Camera Live
================

v002 Camera Live provides a Syphon server for a connected camera, allowing it to be used as a live video feed.

Currently the only supported cameras are Canon DSLRs, see [CAMERAS.md](https://github.com/v002/v002-Camera-Live/blob/master/CAMERAS.md) for a list.

You can download the app from the [releases page](https://github.com/v002/v002-Camera-Live/releases).

Typical latency of a Canon 7D is 120 ms (between 3 and 4 frames at 30 FPS), which is comparable to the latency of the same camera's HDMI output connected to a capture device.

Troubleshooting
---------------

- If your camera model was released after the latest build of Camera Live, it probably isn't supported yet.
- Make sure your camera's firmware is up to date. Firmware updates are available from Canon in your region. 

Changes
-------

See [the change log](https://github.com/v002/v002-Camera-Live/blob/master/CHANGES.md) for details of changes between released builds.

Building From Source
--------------------

To build the project yourself, you must acquire your own copies of the necessary libraries:

 - The Canon EDSDK is available from Canon in your region.
 - libjpeg-turbo is available from http://libjpeg-turbo.virtualgl.org
 - Syphon is available from http://syphon.v002.info
