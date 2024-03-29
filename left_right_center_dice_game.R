library(tidyverse)
library(gganimate)
library(broom)
library(parallel)
library(scales)
library(gifski)
library(svglite)
source("Plots/ggplot_themes.R")

set.seed(44)
project.path <- getwd()
cpu.cores <- detectCores() #number of cores available for parallel processing

# Game design -------------------------------------------------------------

#function for a dice roll
rollDice <- function(n.rolls, max.rolls = 3){
  #function randomly returns one of four possible sides to a die per number of rolls
  #n.rolls is the number of die the player has available
  #max.rolls is the maximum number of rolls they can throw even if the player has additional turns
  
  die.faces <- c("left", "right", "center", "dot", "dot", "dot")
  roll.results <- sample(die.faces,
                         min(n.rolls, max.rolls),
                         replace = TRUE)
  return(roll.results)
}

#function to calculate a new turn within the game
takeTurn <- function(gameDF, player, n.players, rolls, roll.index) {
  #function takes in a dataframe of the game and
  #    returns an updated dataframe with one new turn calculated
  #gameDF is the current data frame of the game to be updated
  #player is the player who will roll the dice
  #n.players is the total number of players playing the game
  #rolls is the results of the rolls from rollDice
  #roll.index is the current turn within the game
  
  #duplicate the current game data frame and...
  #update the current row with the existing number of rolls per each player
  newGameDF <- gameDF
  newGameDF[roll.index, ] <- newGameDF[roll.index - 1,]
  
  #add new results to the roller
  newGameDF[roll.index, player] <-
    sum(
      -(rolls == "left"),
      -(rolls == "right"),
      -(rolls == "center"),
      newGameDF[roll.index - 1, player]
    )
  
  ##add new results to other players
  #roll a Left; if statement accounts for if last player passes to the left to player 1
  if (player == n.players) {
    newGameDF[roll.index, 1] <- sum(rolls == "left",
                                    newGameDF[roll.index - 1, 1])
  } else{
    newGameDF[roll.index, player + 1] <- sum(rolls == "left",
                                             newGameDF[roll.index -1, player + 1])
  }
  
  #roll a Right; if statement accounts for if player 1 passes to the right to player 6
  if (player == 1) {
    newGameDF[roll.index, n.players] <- sum(rolls == "right",
                                            newGameDF[roll.index - 1, n.players])
  } else{
    newGameDF[roll.index, player - 1] <- sum(rolls == "right",
                                             newGameDF[roll.index - 1, player - 1])
  }
  return(newGameDF)
}

#function to play single game of LRC
playLRC <- function(n.players, max.turns = 1000) {
  #function sets up a new game of LRC and returns a finished dataframe
  #n.players is the total number of players within the game
  #max.turns is the total possible turns (required to initialize matrix)
  
  #set up empty game matrix
  gameDF <- matrix(ncol = n.players, nrow = max.turns)
  gameDF[1, ] <- 3
  
  #loop to run the game until one player is left
  for (i in 2:max.turns) {
    player <- (i - 2) %% n.players + 1 #controls who the player is
    roll.results <- rollDice(gameDF[i - 1, player])
    gameDF <-
      takeTurn(
        gameDF = gameDF,
        player = player,
        n.players = n.players,
        rolls = roll.results,
        roll.index = i
      )
    
    #stop game once only one player is left and cut off data frame
    if (sum(gameDF[i, ] > 0) == 1) {
      gameDF <- gameDF[1:i,]
      break 
    }
  }
  gameDF <- as.data.frame(gameDF)
  names(gameDF) <- 1:n.players
  return(gameDF)
}


# Run the game ------------------------------------------------------------

#run a single game
playLRC(n.player = 6)

###set up the simulation
#controls the number of players per game (i.e. game size)
n.player.seq <- c(2:6, 8, 10, 12, 16, 20)

#controls the number of games to simulative per game size
n.sims <- 5000

#list of number of players to map playLRC function over which produces the simulations
total.sims <- rep(n.player.seq, n.sims) %>% sort() 

###run the simulation and name the results
playerResultsDF <- mclapply(total.sims, playLRC, mc.cores = cpu.cores)
names(playerResultsDF) <- paste0(total.sims, "_", 1:n.sims)

# Data clean up -----------------------------------------------------------

#add IDs to each game and turn -- then merge into one long dataframe
cleanedResultsDF <- mclapply(names(playerResultsDF),
                             mc.cores = cpu.cores,
                             function(df) {
  playerResultsDF[[df]] %>%
    rowid_to_column() %>%
    rename(Turn = rowid) %>%
    mutate(Game = as.character(df)) %>%
    separate(col = Game, into = c("GameID.n.players", "GameID.sim"), sep = "_") %>%
    gather(key = Player, value = Rolls.left, -GameID.n.players, -GameID.sim, -Turn) %>%
    mutate(GameID.n.players = as.integer(GameID.n.players),
           GameID.sim = as.integer(GameID.sim),
           Player = as.integer(Player)) %>%
    select(GameID.n.players, GameID.sim, Turn, Player, Rolls.left) %>%
    arrange(GameID.n.players, GameID.sim, Turn, Player)
}) %>% bind_rows()

# EDA and plots -----------------------------------------------------------

#view a single game play
cleanedResultsDF %>%
  filter(GameID.n.players == 6,
         GameID.sim == 2) %>%
  mutate(Player = as.factor(Player)) %>%
  ggplot(aes(x = Turn, y = Rolls.left, group = Player, color = Player)) +
  geom_line() +
  geom_point() +
  light.theme

#histogram of game lengths
cleanedResultsDF %>%
  group_by(GameID.n.players, GameID.sim) %>%
  summarize(Length = max(Turn)) %>%
  ggplot(aes(x = Length)) +
  geom_histogram(binwidth = 10,
                 color = "white") +
  facet_wrap(~ GameID.n.players) +
  light.theme

#histogram of winner by starting position
cleanedResultsDF %>%
  mutate(GameID.n.players = factor(paste0(GameID.n.players, " participants"),
                                   levels = paste0(n.player.seq, " participants"))) %>%
  group_by(GameID.n.players, GameID.sim) %>%
  filter(Turn == max(Turn),
         Rolls.left > 0) %>%
  ggplot(aes(x = Player)) +
  geom_bar(color = "white") +
  scale_x_continuous(breaks = c(NULL, seq(2, max(n.player.seq), 2))) +
  scale_y_continuous(label = scales::comma) +
  facet_wrap( ~ GameID.n.players) +
  labs(title = "Frequency of LRC wins by participant position",
       subtitle = paste0("Results from ", scales::comma(n.sims), " simulations each"),
       x = "Participant by starting position",
       y = "Count of wins") +
  light.theme +
  theme(axis.text.x = element_text(size = 8),
        axis.ticks = element_line(colour = "grey50"))

# ggsave(filename = "Plots/LRC_winners.svg",
#        plot = last_plot(),
#        path = project.path,
#        device = "svg",
#        width = 8,
#        height = 6)

#create plotly and send to server
# p <- ggplotly(ggplot2::last_plot())
# api_create(p, filename = "LRC-winners")
# rm(p)

##position advantage by number of wins grouped by game size
cleanedResultsDF %>%
  group_by(GameID.n.players, GameID.sim) %>%
  filter(Turn == max(Turn),
         Rolls.left > 0) %>%
  group_by(GameID.n.players) %>%
  count(Player) %>%
  group_by(GameID.n.players) %>%
  nest() %>%
  mutate(Win.adv = map(data, function(df) df$n / df$n[1] - 1)) %>% #calculates the average increase in wins by position
  pull(Win.adv) %>%
  unlist() %>%
  enframe() %>%
  select(-name) %>%
  rename(Win.adv = value) %>%
  mutate(player = sapply(n.player.seq, function(x) 1:x) %>% unlist(), #player position identifier
         n.players = rep(paste0(n.player.seq, " participants"), n.player.seq), #game size identifier
         n.players = factor(n.players, #reorder it and add labels
                            levels = paste0(n.player.seq, " participants"))) %>%
  ggplot(aes(x = player, y = Win.adv, label = scales::percent(Win.adv))) +
  geom_col() +
  facet_wrap( ~ n.players) +
  scale_x_continuous(breaks = c(NULL, seq(2, max(n.player.seq), 2))) +
  scale_y_continuous(label = scales::percent) +
  labs(title = "Expected advantage based on position",
       subtitle = paste0("Results from ", scales::comma(n.sims), " simulations each"),
       x = "Participant by starting position",
       y = "% increase in # of wins compared to Participant 1") +
  light.theme +
  theme(axis.text.x = element_text(size = 8),
        axis.ticks = element_line(colour = "grey50"))

# ggsave(filename = "Plots/Player_advantage.svg",
#        plot = last_plot(),
#        path = project.path,
#        device = "svg",
#        width = 8,
#        height = 6)

#what percentage of times did someone lose all their dollars and then go on to win
map_lgl(names(playerResultsDF), function(df) {
  DF <- playerResultsDF[[df]]
  winner <- names(DF)[DF[nrow(DF),] > 0]
  ever.zero <- sum(DF[, winner] == 0) > 0
  return(ever.zero)
}) %>% sum() / length(total.sims)

##how many times did someone lose all their dollars and then go on to win -- grouped by game size
EverZeroDF <- map_df(names(playerResultsDF), function(df) {
  DF <- playerResultsDF[[df]]
  winner <- names(DF)[DF[nrow(DF),] > 0]
  Ever.zero <- sum(DF[, winner] == 0) > 0
  result <- tibble(df, Ever.zero)
  return(result)
}) %>%
  separate(col = df, into = c("GameID.n.players", "GameID.sim"), sep = "_") %>%
  mutate(GameID.n.players = as.integer(GameID.n.players),
         GameID.sim = as.integer(GameID.sim)) %>%
  group_by(GameID.n.players) %>%
  summarize(Percent.ever.zero = sum(Ever.zero) / n.sims)

#plot the % of games where the winner came back from zero
EverZeroDF %>%
  ggplot(aes(x = GameID.n.players, y = Percent.ever.zero)) +
    geom_point() +
    geom_line() +
    scale_x_continuous(breaks = n.player.seq) +
    scale_y_continuous(label = scales::percent) +
    labs(title = "Percent of games where the winner came back after have zero dollars",
         subtitle = paste0("Results from ", scales::comma(n.sims), " simulations"),
         x = "Game size",
         y = "Percent of games") +
    light.theme

# ggsave(filename = "Plots/Comeback_winners.svg",
#        plot = last_plot(),
#        path = project.path,
#        device = "svg",
#        width = 8,
#        height = 6)

# Single game animation ------------------------------------------------------------

#run a game and then build the plot
LRC.plot <- playLRC(n.players = 4) %>%
  rowid_to_column() %>%
  rename(Turn = rowid) %>%
  gather(key = Player, value = Rolls.left, -Turn) %>%
  select(Player, Turn, Rolls.left) %>%
  arrange(Player, Turn) %>%
  ggplot(aes(x = Turn, y = Rolls.left, group = Player, color = Player)) +
  geom_line(alpha = 0.5) +
  geom_segment(aes(xend = max(Turn),
                   yend = Rolls.left),
               linetype = 2) +
  geom_point(size = 3) +
  geom_text(aes(x = max(Turn) + 1,
                label = paste0("Player: ", Player)),
            hjust = 0) +
  scale_color_brewer(palette = "Spectral") +
  transition_reveal(along = Turn) +
  coord_cartesian(clip = 'off') +
  labs(title = "A Single Game of Left Right Center",
       x = "Turn",
       y = "Dollars left") +
  light.theme +
  theme(plot.margin = unit(c(1, 2, 1, 1), "cm"))

#build the animation
LRC.gif <- animate(LRC.plot,
                   fps = 24,
                   duration = 12,
                   end_pause = 24 * 3, #pause for 3 seconds at the end
                   height = 350,
                   width = 500)

# anim_save(animation = LRC.gif,
#           filename = "LRC.gif",
#           path = project.path)


# scratch code ------------------------------------------------------------

#position advantage by number of wins grouped by game size
cleanedResultsDF %>%
  group_by(GameID.n.players, GameID.sim) %>%
  filter(Turn == max(Turn),
         Rolls.left > 0) %>%
  group_by(GameID.n.players) %>%
  count(Player) %>%
  group_by(GameID.n.players) %>%
  nest() %>%
  mutate(Win.adv = map(data, function(df) mean(diff(df$n) / df$n[1]))) %>% #calculates the average increase in wins by position
  pull(Win.adv) %>%
  unlist() %>%
  enframe() %>%
  select(-name) %>%
  rename(Win.adv = value) %>%
  mutate(n.players = n.player.seq) %>%
  ggplot(aes(x = Win.adv, y = n.players, label = scales::percent(Win.adv))) +
  geom_segment(aes(x = 0, y = n.players, xend = Win.adv, yend = n.players),
               color = "grey50") +
  geom_point(size = 10,
             color = "grey40") +
  scale_y_continuous(breaks = n.player.seq) +
  scale_x_log10(labels = scales::percent) +
  geom_text(size = 2.3,
            color = "grey90") +
  labs(title = "Expected advantage based on distance to roller",
       x = "Percent increase in number of wins for each additional position",
       y = "Number of participants in the game") +
  theme(axis.ticks = element_line(colour = "grey50")) +
  light.theme

#linear regression coefficients by game size
cleanedResultsDF %>%
  group_by(GameID.n.players, GameID.sim) %>%
  filter(Turn == max(Turn),
         Rolls.left > 0) %>%
  group_by(GameID.n.players) %>%
  count(Player) %>%
  group_by(GameID.n.players) %>%
  nest() %>%
  mutate(Model = map(data, lm, formula = n ~ Player)) %>%
  pull(Model) %>%
  map(., function(df) {tidy(df)$estimate[2]}) %>%
  unlist() %>%
  as.tibble() %>%
  rename(lmCoefficient = value) %>%
  mutate(n.players = n.player.seq) %>%
  ggplot(aes(x = lmCoefficient, y = n.players, label = round(lmCoefficient, 2))) +
  geom_segment(aes(x = 0,
                   y = n.players,
                   xend = lmCoefficient,
                   yend = n.players),
               color = "grey50") +
  geom_point(size = 10,
             color = "grey40") +
  scale_y_continuous(breaks = n.player.seq) +
  scale_x_log10() +
  geom_text(size = 2.3,
            color = "grey90") +
  labs(title = "Player coefficent from linear model",
       x = "Player coefficient",
       y = "Number of players") +
  theme(axis.ticks = element_line(colour = "grey50")) +
  light.theme
