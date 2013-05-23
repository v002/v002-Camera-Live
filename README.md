v002 Camera Live
================

v002 Camera Live provides a Syphon server for a connected camera, allowing it to be used as a live video feed.

Currently the only supported cameras are Canon DSLRs.

You can download the app here: [v002 Camera Live](http://d1uo0zjpbs7clj.cloudfront.net/Camera%20Live.zip) (build 3)

Typical latency of a Canon 7D is 120 ms (between 3 and 4 frames at 30 FPS), which is comparable to the latency of the same camera's HDMI output connected to a capture device.

Changes
-------

See [the change log](https://github.com/v002/v002-Camera-Live/blob/master/CHANGES.md) for details of changes between released builds.

Building From Source
--------------------

To build the project yourself, you must acquire your own copies of the necessary libraries:

 - The Canon EDSDK is available from Canon in your region. Currently we use version 2.10.0.10 of the SDK as more recent versions are buggy.
 - libjpeg-turbo is available from http://libjpeg-turbo.virtualgl.org
 - Syphon is available from http://syphon.v002.info
