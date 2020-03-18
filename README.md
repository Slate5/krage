# Krage

Krage is a terminal-based game for 2-4 players. There is a map and each player place land on the map next to his owned field. The dominant player is the winner, moreover, the winner becomes The Mighty Krage King!

![https://raw.githubusercontent.com/Slate5/krage/master/data/krage.gif](https://raw.githubusercontent.com/Slate5/krage/master/data/krage.gif)

## Installation

The game works on Ubuntu version 18/19 and ruby > 2.4 (ruby from snap on Ubuntu 19.10 have permission issue so use RVM, apt, etc. or run `krage -s` to avoid error messages):
```
git clone https://github.com/Slate5/krage.git
cd krage && rake
```
## Play

Start the game from the desktop application or run the command from a terminal:
<br/><br/>`krage [-s]`<br/><br/>
For silent game use flag "-s".\
The first start takes up to a few seconds to adjust the screen and other settings.

## Uninstallation

From Krage directory: `rake uninstall && cd`

## Features

- [x] 🔰 - Game style: start game from a corner
- [x] ⚔️ - Game style: start game from the middle
- [x] 🗺 - info: how many more fields player have to own at the end of this round to be a winner
- [x] 🃏 - info: how many fields you have to conquer to gain bonus joker
- [x] ⏳ - earn this by being fast and get extra joker (5 needed)
- [x] 🎯 - try to place land on a map without mistake to gain these (5 needed for joker)
- [ ] 📶 - play over wifi

## Keyboard instruction

| Keyboard | Console |
| -------- | ------- |
|<kbd>r</kbd>| ROLL|
|<kbd>s</kbd>| SKIP|
|<kbd>g</kbd>| GIVEUP|
|<kbd>q</kbd>| ROTATE|
|<kbd>w</kbd>| REROLL|
|<kbd>e</kbd>| EAT|
|<kbd>1</kbd>| Direction 1|
|<kbd>2</kbd>| Direction 2|
|<kbd>3</kbd>| Direction 3|
|<kbd>4</kbd>| Direction 4|
