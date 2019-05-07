# Is it possible beat Left Right Center?
Around the holidays my family enjoys a game of Left Right Center, a chance-based dice game where everyone puts a few dollars on the line. It's a nice reprieve from the typical skill-based games much of family tends to play, and the only decision involved is what position within the family circle do you sit?

## The game
The game consists of each player starting with three one-dollar bills and attempting to be the last person with at least $1 left. The winner takes the full pot of bills. It starts with the first player rolling three die with each face of the six-sided die matching a resulting action:
- a roll of an "L" results in passing one dollar to the person to the left
- a roll of a "R" ...to the right
- a roll of a "C" results in placing one dollar in the middle of the table, removing it from the gameplay
- a roll of a "dot" results in the player keeping the dollar until the next turn. There's three faces of the die that are "dots"

From there on the turn goes around the circle with each player tossing a number of die matching how many dollars they are holding (up to a maximum of three die). Dollars are accumulated and lost but no player is permanantly out of the game until a single dollar is remaining.

![](LRC.gif)

## Simulating it
If the game is totally up to chance then what is the point of simulating it? Is there actually an edge to be had? The expected average outcome of any given turn will result in less dollars for the player since only half the die faces (the dots) result in keeping dollars and the other half result in giving away dollars. Does this mean that its best to go last? Let's see.



