# Gaze-Driven Interaction Modes for VisionGaze

## Summary

VisionGaze's 2–5° webcam error rules out clicking ordinary desktop targets directly by gaze. A 20 pt macOS button covers about 0.4°, while a gaze-safe target needs roughly 6–12°. Every shipping gaze system deals with this the same way. Gaze picks a rough area. Then a second step resolves the exact target: a zoom (Windows Precise Mouse, Talon Zoom Mouse, iOS Zoom on Keyboard Keys) or snapping to the nearest real UI element (iOS Snap to Item). A separate trigger commits the action: dwell, a switch, a noise or a pinch. VisionGaze should add a two-stage "zoom-then-dwell" click with progress feedback, snap-to-element using the macOS Accessibility tree, and an action launchpad. Gaze typing should come later.

## Key findings

- **Dwell timing is learnable and should adapt.** In Majaranta et al. (CHI 2009), novices started at 1000 ms. Over 10 sessions, mean dwell dropped from 876 ms to 282 ms. Typing speed rose from 6.9 to 19.9 wpm, and errors fell from 1.28% to 0.36%. Most users settled at 300–400 ms after about an hour. Dwells of 200 ms were reachable but not sustainable.
- **Feedback matters.** Majaranta's feedback studies found that a visible dwell-progress animation plus a confirmation cue at selection improves speed and accuracy. A shrinking or filling ring is now the standard design.
- **Windows Eye Control** splits dwell into two settings: *Typing dwell* for keys and *General dwell* for function keys, predictions and mouse controls. It uses a **launchpad** with buttons for left click, right click, Precise mouse, scroll, keyboard, TTS, Start, Task view, calibrate, settings and **Pause**. With **Precise mouse**, you look at the area, fine-tune the cursor, then choose left, right or double click. The gaze cursor is optional and appears only while dwelling. **Shape writing** lets you dwell on the first letter, glance through the middle letters, then dwell on the last letter.
- **iOS 18 Eye Tracking** has five controls. *Smoothing* is a slider that trades smoothness against lag. *Snap to Item* moves the pointer to the nearest selectable element. *Zoom on Keyboard Keys* zooms into the keyboard region you look at, and a second dwell taps the key. *Auto-Hide* shows the pointer only while your gaze is steady. *Dwell Control* is on by default and lives under AssistiveTouch, along with movement tolerance and hot-corner actions. Snap to Item is what makes iOS usable at low accuracy.
- **Talon Zoom Mouse** uses eye tracking alone. A trigger magnifies the gazed region, a second look-and-trigger clicks inside the magnified view, and pop or hiss noises serve as click and drag triggers. This is the closest match to VisionGaze's accuracy situation.
- **Dwell-free typing is much faster.** Kristensson and Vertanen's simulation (ETRA 2012) reached a mean of **46 wpm** after 40 minutes. A real build, EyeSwipe, reached **11.7 wpm** after 30 minutes, with an expert at 20.6 wpm, and users found it more comfortable than dwell typing. Dasher, which steers continuously and zooms into probable letters, and GazeTalk, which uses large predictive keys, both tolerate low accuracy by design.
- **Target sizing.** Feit et al. (CHI 2017) found that accuracy and precision vary more than 6× between users and screen regions. They size targets so that 95% of gaze samples land inside: roughly **S = 2·(offset + 2·SD)** per axis. With good IR trackers, the minimum is about **1.9 × 2.35 cm**. At 60 cm, 1° ≈ 1.05 cm, which is about 50 pt on a 13–14" MacBook. For VisionGaze, assuming 2° offset and 1° SD, targets need about **8° (~8 cm)**, and about **14°** at 5° offset.

## Recommendations (ranked)

1. **Zoom-then-dwell click (default mode).** Gazing steadily within a 3° radius for **600 ms** opens a magnifier of about 9° (3× zoom) centred on the gaze. A second dwell inside it clicks at the mapped point. A dwell ring fills over the dwell time, followed by a click flash or sound. Add a **1000 ms cooldown** after each click, and make the next dwell require the gaze to leave and re-enter the area. Expose a slider from 300 to 1500 ms. Optionally lower the dwell automatically as error rates fall, never below 300 ms.
2. **Snap-to-element.** Query the macOS AX tree (AXButton, AXLink, AXMenuItem and similar) near the gaze point and pull the cursor to the nearest actionable element within about 4°. When there is exactly one candidate, skip the zoom and click with a single dwell. This works like iOS Snap to Item and fixes most clicks in native apps.
3. **Gaze launchpad and click-type palette.** Add a small edge-docked panel with large buttons (≥8°): Left, Right, Double, Drag-lock, Scroll, Keyboard, Recalibrate and **Pause**. The chosen click type applies to the next zoom-click, as in Windows Eye Control. Pause matters because it fixes the Midas-touch problem, where everything you look at gets clicked. Use a General dwell of 800 ms on the launchpad, separate from the target dwell.
4. **Trigger fusion with ManOS and external triggers.** Let gaze set *where* and let a ManOS pinch, a hotkey, a foot switch or a mouth noise (like Talon's pop) set *when*. That trigger replaces the second dwell. Turn this on by default whenever ManOS is running, because a separate trigger avoids Midas-touch better than dwell does.
5. **Gaze scroll zones.** Looking at the top or bottom 10% of a scrollable window for 400 ms or more scrolls it, with speed proportional to depth into the zone. Toggle this from the launchpad.
6. **Gaze keyboard (later).** Start with a large-key on-screen keyboard (about 8° keys, GazeTalk-style, with word prediction and a 400 ms typing dwell). Then add dwell-free swipe or shape writing in the EyeSwipe style. Treat Dasher integration as an optional mode.
7. **Display and filtering defaults.** Hide the cursor by default and show it only during dwell (iOS Auto-Hide). Smooth the cursor with a 1€ filter or a fixation-aware filter so it sits still during fixations and jumps quickly on saccades. Enlarge the margins near screen edges, where Feit et al. measured worse accuracy.

## Sources

- https://support.microsoft.com/en-us/accessibility/windows/eye-control/eye-control-basics-in-windows
- https://products.support.services.microsoft.com/en-us/windows/eye-control-troubleshooting-guide-83352d28-688a-e29c-4b5f-e91aee324259
- https://mcmw.abilitynet.org.uk/how-to-control-your-device-using-eye-tracking-in-ios-18-on-your-iphone-or-ipad
- https://support.apple.com/guide/iphone/control-iphone-with-the-movement-of-your-eyes-iph66057d0f6/ios
- https://medium.com/hubabl/make-your-mac-hands-free-part-1-fe70980f36b (Talon zoom mouse, noises)
- https://talon.wiki/Resource%20Hub/Hardware/tobii_4c/
- https://homepages.tuni.fi/oleg.spakov/publications/Majaranta_CHI_09.pdf
- https://www.researchgate.net/publication/220606553_Effects_of_feedback_and_dwell_time_on_eye_typing_speed_and_accuracy
- https://keithv.com/pub/dwellfree/kristensson-dwell-free.pdf
- https://www.researchgate.net/publication/301931751_EyeSwipe_Dwell-free_Text_Entry_Using_Gaze_Paths
- https://www.microsoft.com/en-us/research/wp-content/uploads/2017/01/everyday_eyetracking-1.pdf
- https://pokristensson.com/pubs/HamidKristenssonETRA2024.pdf
