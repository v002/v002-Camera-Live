v002 Camera Live
================

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

Changes
-------

See [the change log](https://github.com/v002/v002-Camera-Live/blob/master/CHANGES.md) for details of changes between released builds.

Building From Source
--------------------

To build the project yourself, you must acquire your own copies of the necessary libraries:

 - The Canon EDSDK is available from Canon in your region.
 - libjpeg-turbo is available from http://libjpeg-turbo.virtualgl.org
 - Syphon is available from http://syphon.v002.info

Code-signing the Canon SDK when you export an Archive build throws up a couple of challenges:

 - You will have to add a ````CFBundleSupportedPlatforms```` entry to the Info.plist of some of the Canon bundles within EDSDK.framework (try it and you will see error messages for each affected bundle)
 - You will have to relocate anything that isn't loadable code from EDSDK.framework/Versions/A/ and edit the EDSDK binary to update the new location if it is referenced. I moved ````Versions/Current/DeviceInfo.plist```` to ````Versions/A/Resources/ceInfo.plist```` (to avoid changing the length of strings in the EDSDK binary).
