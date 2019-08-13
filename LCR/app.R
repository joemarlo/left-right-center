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



# Plot theme --------------------------------------------------------------

#define plot theme
seashell.theme <- theme(panel.grid.minor = element_line(color = NA),
                        panel.background = element_rect(fill = "seashell2"),
                        plot.background = element_rect(fill = "seashell",
                                                       color = NA),
                        axis.title = element_text(color = "gray30",
                                                  size = 12),
                        strip.background = element_rect(fill = "seashell3"),
                        plot.title = element_text(color = "gray30",
                                                  size = 14,
                                                  face = "bold"))

# Define UI for application that draws a histogram
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
         sliderInput(inputId = "turn",
                     label = "Turn",
                     min = 1,
                     max = 100,
                     value = 1,
                     animate = animationOptions(interval = 400,
                                    loop = FALSE))
      ),
      
      # Show a plot of the generated distribution
      mainPanel(
         plotOutput("distPlot")
      )
   ),

   actionButton(inputId = "refreshButton",
                label = "Refresh plot"),
   plotOutput("rys")
   
   )

# Define server logic required to draw a histogram
server <- function(input, output) {
   
  pp <- eventReactive(c(input$refreshButton,input$players),{
      LRCgame <- playLRC(n.players = input$players) %>%
        rowid_to_column() %>%
        rename(Turn = rowid) %>%
        gather(key = Player, value = Rolls.left, -Turn) %>%
        select(Player, Turn, Rolls.left) %>%
        arrange(Player, Turn)
      
      xMax <- max(input$players*20,
                  max(LRCgame$Turn))
      yMax <- max(6,
                  max(LRCgame$Rolls.left))

      # generate based on input$bins from ui.R
      LRCgame %>%
        ggplot(aes(x = Turn, y = Rolls.left, group = Player, color = Player)) +
        geom_line(alpha = 0.5) +
        # geom_segment(aes(xend = max(Turn),
        #                  yend = Rolls.left),
        #              linetype = 2) +
        geom_point(size = 1) +
        # geom_text(aes(x = max(Turn) + 1,
        #               label = paste0("Player: ", Player)),
        #           hjust = 0) +
        scale_color_brewer(palette = "Spectral") +
        scale_y_continuous(limits = c(0, yMax),
                           breaks = 1:yMax) +
        scale_x_continuous(limits = c(0, xMax),
                           breaks = seq(0, xMax, floor(xMax / 10))) +
        coord_cartesian(clip = 'off') +
        labs(title = "Dollars left per player",
             x = "Turn",
             y = "Dollars") +
        seashell.theme +
        theme(plot.margin = margin(5.5, 50, 5.5, 5.5),
              panel.background = element_rect(fill = "seashell"))
  })
  output$rys <- renderPlot({
    pp()
  })
  
   # output$distPlot <- renderPlot({
   #   
   #   #run the game
   #   LRCgame <- playLRC(n.players = input$players) %>%
   #     rowid_to_column() %>%
   #     rename(Turn = rowid) %>%
   #     gather(key = Player, value = Rolls.left, -Turn) %>%
   #     select(Player, Turn, Rolls.left) %>%
   #     arrange(Player, Turn) 
   #   
   #   # generate bins based on input$bins from ui.R
   #   LRCgame %>%
   #     ggplot(aes(x = Turn, y = Rolls.left, group = Player, color = Player)) +
   #     geom_line(alpha = 0.5) +
   #     # geom_segment(aes(xend = max(Turn),
   #     #                  yend = Rolls.left),
   #     #              linetype = 2) +
   #     geom_point(size = 1) +
   #     # geom_text(aes(x = max(Turn) + 1,
   #     #               label = paste0("Player: ", Player)),
   #     #           hjust = 0) +
   #     scale_color_brewer(palette = "Spectral") +
   #     coord_cartesian(clip = 'off') +
   #     labs(title = "Dollars left per player",
   #          x = "Turn",
   #          y = "Dollars") +
   #     seashell.theme +
   #     theme(plot.margin = margin(5.5, 50, 5.5, 5.5),
   #           panel.background = element_rect(fill = "seashell"))
   # 
   # })
}

# Run the application 
shinyApp(ui = ui, server = server)

