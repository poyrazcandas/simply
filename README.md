# simply.

A Mac habit tracker I made for myself.

During the medieval times, this used to be a little local web app I kept open in a browser tab during my first days of streamlit. Eventually got tired of that, so remade it as an actual Mac app. Pretty basic yet essential stuff.

There's a Daily screen with morning / day / night habits, a progress bar so you can see if the day actually filled up, and a reflection box at the bottom. Habits you can add and rearrange. Insights if you want to see streaks and which habits tend to go with better days. That's pretty much the whole thing.

No account. No cloud. Nothing leaves your machine. The way true geeks love.

## actually running it

Open `simply.xcodeproj` in Xcode and hit Run - Needs macOS 14+.

Your data lives in:

```
~/Library/Application Support/simply/tracker.json
```

That's the whole database. If you care about your logs, don't delete that file lol.

## notes (there is more stuff but these may be harder to catch)

Weekdays assume a fuller day than weekends. I didn't want to toggle that every Friday night.

There's a to-do / calendar tab sitting in the code, switched off. Might turn it on later.

Under MIT License. Use it, fork it, ignore it, whatever. I'd be very happy if anyone used this for any purpose of their own.
