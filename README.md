# Krage

Krage is a terminal-based game for 2-4 players. Each player puts a piece of land on the map next to his conquered field. The dominant player is the winner, who becomes The Mighty Krage King!

![](data/krage.gif)

## Installation

The game works on Ubuntu 18 or later versions, Ruby > 2.4 (Ruby from snap on Ubuntu 19.10 has permission issue, so please use RVM, apt, etc. or run `krage -s` to avoid error messages):
```
git clone https://github.com/Slate5/krage.git
cd krage && rake
```

## Play

Start the game from desktop or run the command from a terminal:
<br/><br/>`krage [-s]`<br/><br/>
For silent game use flag "-s".\
The first start takes up to a few seconds to adjust the screen and other settings.

## Uninstallation

From Krage directory: `rake uninstall && cd`

## Features

- [x] 🔰 - Game style: start game from a corner
- [x] ⚔️ - Game style: start game from the middle
- [x] 📖 - Fields: how many more fields player has to own at the end of this round to be a winner
- [x] 📖 - Jokers: how many fields you have to conquer to gain bonus joker
- [x] ⏳ - earn this by being fast and get extra joker (5 needed)
- [x] 🎯 - try to place land on the map without mistake to gain these (5 needed for a joker)
- [ ] 📶 - play over the internet

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
