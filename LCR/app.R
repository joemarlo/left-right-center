library(shiny)
library(tidyverse)

# Define game logic -------------------------------------------------------

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
  #function takes in a dataframe of the game and...
  #returns an updated dataframe with one new turn calculated
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
  #function sets up a new game of LRC and returns a finished matrix
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


# UI ----------------------------------------------------------------------

ui <- fluidPage(
   
   # Application title
   titlePanel("Simulating Left Right Center"),
   
   # Sidebar with a slider input for number of bins 
   sidebarLayout(
      sidebarPanel(
         sliderInput(inputId = "players",
                     label = "Number of players:",
                     min = 2,
                     max = 20,
                     value = 6),
         sliderInput(inputId = "n.sims",
                     label = "Number of simulations",
                     min = 100,
                     max = 1000,
                     value = 100,
                     step = 100)
      ),
      
      # Show a plot of the generated distribution
      mainPanel(
        tabsetPanel(
          tabPanel("Winners", plotOutput("plotWinners")),
          tabPanel("Game Lengths", plotOutput("plotLengths"))
        )
      )
   )
  )


# Server ------------------------------------------------------------------

server <- function(input, output, session) {
  
  # Run the simulation and return a dataframe containing each games play-by-play
  selectedData <- reactive({
    
    total.sims <- rep(input$players, input$n.sims)
    
    ###run the simulation and name the results
    playerResultsDF <- lapply(total.sims, playLRC)
    names(playerResultsDF) <- paste0(total.sims, "_", 1:input$n.sims)
    
    data <- lapply(names(playerResultsDF), function(df) {
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
        arrange(GameID.n.players, GameID.sim, Turn, Player)}) %>% bind_rows()
    
    return(data)
    
    })
  
  # plot the games' winners
  output$plotWinners <- renderPlot({
    selectedData() %>%
      group_by(GameID.n.players, GameID.sim) %>%
      filter(Turn == max(Turn),
             Rolls.left > 0) %>%
      ggplot(aes(x = Player)) +
      geom_histogram(binwidth = 1,
                     color = "white") +
      scale_x_continuous(breaks = 1:input$players,
                         name = "Winning player")
  })
  
  # plot the length of each game
  output$plotLengths <- renderPlot({
    selectedData() %>%
      group_by(GameID.n.players, GameID.sim) %>%
      summarize(Length = max(Turn)) %>%
      ggplot(aes(x = Length)) +
      geom_histogram(binwidth = 10,
                     color = "white") +
      xlab("Total number of turns played")
  })

}

# Run the application 
shinyApp(ui = ui, server = server)

