# Irish Life Demo OBS Overlay

This page documents a simple OBS browser-source overlay for Irish Life end-to-end demo recordings on macOS.

The overlay is intended for a full-screen recording where the left 25% of the capture is the customer journey and the right 75% is the agent journey.

## Files

- Browser overlay HTML: [docs/assets/obs/irish-life-dual-screen-overlay.html](docs/assets/obs/irish-life-dual-screen-overlay.html)

## What It Shows

- a top-left label for `Customer experience`
- a top-right label for `Agent experience`
- a vertical divider at the 25% mark of the frame
- a light visual frame around each side so the 25/75 split reads clearly during the recording

## OBS Setup On macOS

If this is your first time using OBS, think of a `source` as one visual layer in the recording. You will create two sources:

- a screen capture source for your Mac display
- a browser source for the overlay labels and divider

Follow these steps:

1. Open OBS.
2. In the `Scenes` panel, keep the default scene or create a new one for this recording.
3. In the `Sources` panel, click the `+` button.
4. Choose `macOS Screen Capture` if OBS shows that option. If your OBS version still shows `Display Capture`, you can use that instead.
5. Give it a clear name such as `Main Screen`, then click `OK`.
6. If OBS asks which display to capture, choose the Mac screen you want to record, then click `OK`.
7. You should now see your desktop in the OBS preview.
8. In the `Sources` panel, click the `+` button again.
9. Choose `Browser`.
10. Give it a name such as `Irish Life Overlay`, then click `OK`.
11. In the browser source settings window, enable `Local file`.
12. Click `Browse` and select `project-docs/docs/assets/obs/irish-life-dual-screen-overlay.html`.
13. Set `Width` and `Height` to match the resolution you plan to record at:
	- use `1920` x `1080` for a standard full HD recording
	- use `3840` x `2160` only if your OBS canvas and final recording are set to 4K
14. Leave the page background transparent so only the labels, divider, and frame appear on top of your screen capture.
15. Click `OK` to create the browser source.
16. In the `Sources` list, make sure the browser source is above the screen capture source so the overlay stays visible.
17. If the overlay does not fill the preview correctly, click the browser source in the preview and resize it to match the canvas.
18. When it looks right, click the padlock icon next to the browser source in the `Sources` list so you do not move it by accident.

You are ready to record once both the screen capture and the overlay are visible in the OBS preview.

## Audio Notes For A Basic Recording

The steps above ensure you can record your screen and the overlay. They do not automatically guarantee every type of audio.

- If you want to record your microphone, add another source in OBS and choose `Audio Input Capture`, then select your microphone.
- If you want to record the sound coming from your Mac, `macOS Screen Capture` can capture system audio on newer macOS and OBS versions.
- If your OBS setup does not show system audio in the Audio Mixer, you will need a separate macOS audio capture setup, as described in the OBS macOS desktop audio guide.

Before recording, check the `Audio Mixer` panel in OBS:

1. Speak into the microphone and confirm the meter moves if you want voice audio.
2. Play a short sound on the Mac and confirm the desktop or screen capture audio meter moves if you want system audio.
3. Make a short test recording and play it back before doing the real demo.

## Choosing 1080p Or 4K

For most demo recordings, `1920 x 1080` is the right default. It is easier to manage, produces smaller files, and is usually sharp enough for screen recordings and video calls.

Use `3840 x 2160` only if all of the following are true:

- your external monitor is running at 4K resolution
- your OBS `Base Canvas` and `Output Resolution` are also set to `3840 x 2160`
- you want the final exported video in 4K
- your Mac can record smoothly at that resolution without dropped frames

If you are using a MacBook Pro connected to a 32-inch external display, the screen size alone does not mean you should use 4K. What matters is the actual resolution selected for that external display and the resolution you want for the final video.

To check what your display is using on macOS:

1. Open `System Settings`.
2. Go to `Displays`.
3. Select the external monitor.
4. Check the current resolution shown for that monitor.

If you are unsure, use `1920 x 1080` in OBS first. That is the safest starting point for a clean demo recording.

## How To Test A Recording

Use this quick test before the real demo:

1. In OBS, confirm you can see the screen capture and the overlay in the preview.
2. In the `Audio Mixer`, confirm the meters move for any microphone or system audio you want to keep.
3. Click `Start Recording`.
4. Record 10 to 15 seconds while doing a few real actions:
	- move the mouse
	- open the app or browser you will demo
	- speak a sentence if you want microphone audio
	- play a short sound if you want system audio
5. Click `Stop Recording`.
6. In OBS, open `File` then `Show Recordings`.
7. Open the newest video file and check four things:
	- the full screen is visible
	- the overlay labels and divider are aligned correctly
	- the text is readable
	- the audio is present and clear

If the video looks soft or blurry, first check whether OBS is set to `1920 x 1080` or `3840 x 2160`, then make sure the browser overlay source uses the same size.

## Recording Layout Suggestion

- Place the customer browser or wallet simulator in the left quarter of the screen.
- Place the agent UI or operator console in the right three quarters.
- Use a browser zoom level that keeps the important call-to-action controls visible without scrolling.
- Keep the OBS overlay source at the top of the scene so the labels and divider remain visible throughout the demo.

## Quick Tweaks

If you want to restyle it, edit the CSS custom properties near the top of the HTML file.

- `--left-accent` controls the customer-side label color.
- `--right-accent` controls the agent-side label color.
- `--divider-core` controls the center line.

If you need a 4K version in OBS, keep the same file and set the browser source to `3840 x 2160`.

The overlay uses relative sizing so it scales cleanly.
