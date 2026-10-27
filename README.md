# simply

A Mac habit tracker I made for myself.

This used to be a little local web app I kept open in a browser tab. I got tired of that, so I remade it as an actual Mac app. Same idea: check off the day, write a sentence about it, move on.

There's a Daily screen with morning / day / night habits, a progress bar so you can see if the day actually filled up, and a reflection box at the bottom. Habits you can add and rearrange. Insights if you want to see streaks and which habits tend to go with better days. That's pretty much the whole thing.

No account. No cloud. Nothing leaves your machine.

## running it

Open `simply.xcodeproj` in Xcode and hit Run. Needs macOS 14.

Your data lives here:

```
~/Library/Application Support/simply/tracker.json
```

That's the whole database. If you care about your logs, don't delete that file.

## notes

Weekdays assume a fuller day than weekends. I didn't want to toggle that every Friday night.

There's a to-do / calendar tab sitting in the code, switched off. Might turn it on later.

MIT. Use it, fork it, ignore it, whatever.
