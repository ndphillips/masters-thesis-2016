# ------------------------------
#  ShinyBandit
#
#   CODE SECTIONS
#
#   0: Load libraries
#   A: Setup Game
#     A1: Game parameters
#     A2: Data saving
#   B: Overall layout
#   C: Reactive values
#   D: Page layouts
#   E: Event (button) actions
#     F1: Page navigation buttons
#     F2: Event tracking
#   F: Save data
# ------------------

# --------------------------
# Section 0: Load libraries ----
# --------------------------
library(shiny)
library(shinyjs)
library(rdrop2)


# --------------------------
# Section A: Setup game     -----
# --------------------------

# Section A1: GAME PARAMETERS

condition <- 4

nTrials <- 25
nTrialsPractice <- 25
n.games <- 11 # inclusive practice game
game <- 1

m.practice <- 4
sd.practice <- 2

# number of draws, means and sds of the 2 options

m1 <- 4
m2 <- 4

sd1 <- 2.5
sd2 <- 11

# no goal

goal <- 100
goal.practice <- 100

bonus <- 150



# Option outcomes as a list
outcomes <- list()
for (ga in 1:n.games){
  if (ga == 1){
    outcomes.temp <- cbind(round(rnorm(nTrialsPractice, m.practice, sd.practice), 0),
                           round(rnorm(nTrialsPractice, m.practice, sd.practice), 0))
  }
  if (ga > 1){
    outcomes.temp <- cbind(round(rnorm(nTrials, m1, sd1), 0),
                           round(rnorm(nTrials, m2, sd2), 0))
  }
  
  outcomes[[ga]] <- outcomes.temp
}

options.n <- ncol(outcomes[[1]])



locations.r <- matrix(NA, ncol = 2, nrow = n.games)
# Randomize option locations
for (ga in 1:n.games){
  locations.r[ga, 1:2] <- sample(1:2)
  outcomes[[ga]] <- outcomes[[ga]][,locations.r[ga,]]
}

option.order <- NULL
for (rows in 1:nrow(locations.r)){
  option.order <- c(option.order, paste(locations.r[rows,], collapse = ";"))
}
option.order <- c(rep(option.order[1], nTrialsPractice), rep(option.order[2:length(option.order)], each = nTrials))


# --------------------------
# Dropbox Parameters
# --------------------------

EPtoken <- readRDS("EP_droptoken.rds")          # Reads in authentication for EP dropbox
outputDir <- "msteiner/GoalBanditJava/data"          # Determine dropbox output folder
idDir <- "msteiner/GoalBanditJava/ids"
expContrDir <- "msteiner/GoalBanditJava/expControll"
link.i <- "https://econpsychbasel.shinyapps.io/Questionnaire4/"

linkPage =paste0("location.href='",link.i , "';")

ids.df <- read.csv("www/workerIdDatabase.csv")

# --------------------------------
# Section B: The user Interface and its JavaScript logic to run the game----
# -------------------------------

ui <- fixedPage(
  
  title = "Boxes Game",
  uiOutput("MainAction"),
  includeCSS("style.css"),
  includeScript("script.js"),
  useShinyjs()
                   )


server <- function(input, output, session) {
  
  # --------------------------------
  # Section C: Define Reactive Values ----
  #   These store the main values in the game
  # --------------------------------
  
  # CurrentValues stores scalers representing the latest game outcomes
  
  # CurrentValues stores scalers representing the latest game outcomes
  CurrentValues <- reactiveValues(page = "welcome",
                                  game = 1,
                                  trials.max = nTrials,
                                  nGoalsReached = 0,
                                  checkFails = 0,
                                  payout = 0,
                                  checkOK = 0)
  
  # GameValues stores vectors of histories
  GameData <- reactiveValues(trial = c(),          
                             time = c(),
                             selection = c(),
                             outcome = c(),
                             points.cum = c(),
                             game = c())
  
  
  # --------------------------------
  # Section D: Page Layouts ----
  # --------------------------------
  
  # Send the maximum pumpvalue to the Javascript part, so it knows how big to draw the balloon:

  # Send dynamic UI to ui - DON'T CHANGE!
  output$MainAction <- renderUI( {
    PageLayouts()
  })
  
  PageLayouts <- reactive({
    
    # 1) WELCOME PAGE
    if (CurrentValues$page == "welcome") {
      
      return(
        div(class = "welcome", checked = NA,
            list(
              tags$br(), tags$br(), tags$br(),
              h1("Decision Making", class = "firstRow"),
              p("If you consent to participating in this study, please enter your mturk WorkerID below and click Continue."),
              textInput(inputId = "workerid", 
                        label = "Please enter your WorkerID", 
                        value = "", 
                        placeholder = "e.g.; AXLDKGHSJM"),
              # This displays the action putton Next.
              tags$br(),
              disabled(actionButton(inputId = "gt_inst1", 
                                    label = "Continue", class = "continueButtons"))
            )
        )
      )}
    
    # Not Allowed Page
    if (CurrentValues$page == "notAllowed") {
      return(
        div(class = "page2", checked = NA,
            list(
              tags$br(), tags$br(), tags$br(),
              h2(paste0("You entered the WorkerID ", input$workerid,"."), class = "firstRow"),
              p("Sorry but you are not eligible for this HIT because you completed a similar HIT in the past.", id = "notEligible"),
              p("You may now close this window.")
            )
        )
      )
    }
    # INSTRUCTIONS INTRO
    
    if (CurrentValues$page == "inst1") {
      return(
        div(class = "inst", checked = NA,
            list(
              tags$br(), tags$br(),
              h2("Please read the instructions carefully!", class = "firstRow"),
              p("In this study, you will play the Boxes Game and then answer a few brief questionnaires. In total, this HIT should take around 20 minutes to complete."),
              h3("If the page crashes, email us at turkpsych@gmail.com"),
              p("Please note that we are running this HIT on a server that occasionally, but rarely, crashes. If the page crashes while you are completing it, it is important that you let us know right away. If this happens please email us at turkpsych@gmail.com and we will give you further instructions."),
              h3("Read instructions carefully!"),
              p("On the next page we explain how the Boxes game works. Please read the instructions carefully. The better you understand the instructions, the better you will do."),
              tags$br(),
              actionButton(inputId = "gt_inst2", 
                           label = "Continue", class = "continueButtons") 
            )
        )
      )
    }
    # 3) INSTRUCTIONS
    if (CurrentValues$page == "inst2") {
      
      return(
        div(class = "inst", checked = NA,
            list(
              tags$br(),
              h2("The Boxes Game", class = "firstRow"),
              p("The main part of this HIT is the Boxes Game. In each game, you will see two boxes."),
              p(paste("Each box contains a mixture of negative and positive point values ranging anywhere from a possible minimum of -100 to a possible maximum of +100. However, the distribution of values is different in each box. Some boxes have, on average, higher points than others, and some boxes have a wider range of point values than others. When you start a game, you won't know anything about each box. Over the course of the game, you can learn about boxes and earn (or lose) points by using a budget of", nTrials, "clicks.")),
              h3(paste("Using", nTrials, "clicks to learn about boxes and earn points")),
              tags$p("At the top of the screen you will always see three important pieces of information: The number of clicks you have remaining in the game, the total number of points you have earned so far in the game and the goal."),
              h3("Here is a screenshot of how the game will look:"),
              tags$br(),
              fixedRow(column(12, align ="center", tags$img(src = "instGoal.PNG"))),
              # fixedRow(column = 12, plotOutput("InstructionDisplay")),
              # fixedRow(column = 12, plotOutput("resultsDisplayInstructions")),
              p(paste("To use one of your", nTrials, "clicks, you can click on one of the boxes. When you click on a box, the computer will randomly select one of the box's point values. This point value will be displayed in the box. The drawn point value will then be added to your point total (or subtracted from it if the value is negative). The number of clicks you have remaining will then decrease by 1. When you have 0 clicks remaining, the game will end.")),
              h3("Reach 100 points to earn a bonus!"),
              p("If you end a game with 100 points or more, you will earn a 25 cents bonus for that game. If you end a game with fewer than 100 points, you will not receive a 25 cent bonus for that game. The specific point value you reach does not matter for your bonus, it only matters if you end with at least 100 points or not."),
              h3("Points are returned to the boxes"),
              p("The computer will always draw a random point value from the box and will always return that point value back to the box. In other words, the distribution of point values in each box",  strong("will not change over time as a result of your clicks. The distributions will also not change over games although the position of the boxes will randomly vary.")),
              tags$br(),
              actionButton(inputId = "gt_goalInst", label = "Continue", class = "continueButtons"),
              tags$br(),tags$br(),tags$br()
            )
        )
      )}
    
    
    # 3.5) GOAL INSTRUCTIONS
    if (CurrentValues$page == "goalInst") {
      
      return(
        div(class = "inst", checked = NA,
            list(
              tags$br(), tags$br(),
              h2("End a game with 100 points to earn a bonus", class = "firstRow"),
              p("If, at the end of a game, you have earned at least 100 points, you", strong(paste("will earn an extra bonus of 25 cents for that game.")), "If you do not end the game with 100 points or more, you will not earn a bonus for that game."),
              p("For example:"),
              p("If you", strong("end a game with 90 points"), " (less than the goal of 100) you won't receive 25 cents for that game"),
              p("If you", strong("end a game with 110 points"), "(more than the goal of 100), then you", em("will"), "receive 25 cents for that game."),
              p("The specific number of points you earn doesn't matter, it only matters if you end the game above below 100 points. That is, it doesn't matter if you end a game with 100 points or 150 points, in both cases you will still earn a fixed bonus of 25 cents for that game."),
              p("You will only receive the bonus if you", strong("end"), "the game with at least 100 points. This means that, even if you are above 100 points in the middle of the game, if you end the game with fewer than 100 points, then you won't earn the bonus."),
              h3("Your final bonus is added across all games"),
              p("Again, you will play the Boxes Game 10 times. Your final bonus for this HIT will be the sum of your bonuses across all games. For example if you earn a 25 cent bonus in 3 games out of 10, you will receive a bonus of 3 x 25 cents, i.e. 75 cents."),
              h3("It is difficult to reach 100 points."),
              p("It is not easy to reach 100 points in the Boxes Game. You can increase your chance of reaching 100 points based on how you play the game. However, the game is difficult and there will always be a chance you will not be able to reach 100 points. So if you fail to reach 100 points in a game, don't get discouraged and try again in the next game."),
              tags$br(),
              actionButton(inputId = "gt_instCheck", label = "Continue", class = "continueButtons")
            )
        )
      )}
    
    # 3) INSTRUCTIONS Check
    if (CurrentValues$page == "instCheck") {
      
      return(
        div(class = "inst", checked = NA,
            list(
              tags$br(),
              h2("Did you understand the rules?", class = "firstRow"),
              p("Before you start the game, we'd like to make sure you understood the instructions. Please answer the following questions from what you've learned in the instructions before. Please do", strong("not use the return button of your browser"), br(), "If your answer is incorrect you will simply be sent back to the instructions again."),
              tags$br(),
              radioButtons("checkGoal",
                           label = "What happens if I end a game with l00 points or more?",
                           choices = list("I will earn a bonus of exactly 25 cents for that game." = 1,
                                          "I will earn a bonus of the number of total points I earn, plus a bonus of 25 cents." = 2),
                           selected = character(0),
                           width = "800px"),
              radioButtons("checkChange",
                           label = "Can the point values within boxes change substantially over time?",
                           choices = list("Yes, the point values of boxes can substantially change over time." = 1,
                                          "No, while there is random variation in the specific outcomes drawn from boxes, they do not substantially change over time." = 2),
                           selected = character(0),
                           width = "800px"),
              tags$br(),
              actionButton(inputId = "gt_inst3", label = "Continue", class = "continueButtons"),
              tags$br(),tags$br(),tags$br()
            )
        )
      )}
    
    
    # SCREEN FAILED CHECK
    if (CurrentValues$page == "failedCheck") {
      
      return(
        div(class = "inst", checked = NA,
            list(
              tags$br(), tags$br(),
              h3("Sorry, wrong answer. Please read the instructions again."),
              p("Sorry, you did not answer one of the comprehension questions correctly. Click continue to read the instructions again."),
              tags$br(),
              actionButton(inputId = "gt_inst2", label = "Continue", class = "continueButtons")
            )
        )
      )}
    
    # 4) PRACTICE GAME INSTRUCTIONS
    
    if (CurrentValues$page == "inst3") {
      return(
        div(class = "inst", checked = NA,
            list(
              tags$br(), tags$br(),
              h2("Play a Practice Game", class = "firstRow"),
              p("Now you can play a practice game."),
              p(paste("In the practice game, you will have", nTrialsPractice, "clicks to see how the interface works.")),
              p("The points you earn in the practice game don't matter, and all the boxes in the practice game have the same point values, so feel free to play around and experiment."),
              p(strong(paste0("When you finished a game, that is, once you arrive at trial ", nTrialsPractice, ", a button labeled \"Click to Continue to next Game\" will appear. Click it to continue..."))),
              tags$br(),
              actionButton(inputId = "gt_practicegame", 
                           label = "Start Practice Game", class = "continueButtons") 
            )
        )
      )
    }
    
    
    # 3) practice game PAGE
    if (CurrentValues$page %in% c("practicegame", "game")) {
      
      session$sendCustomMessage(type = 'envHandler', list(eno = outcomes[[CurrentValues$game]][,1],
                                                          ent = outcomes[[CurrentValues$game]][,2],
                                                          ens = outcomes[[CurrentValues$game]][,2] + sample(-2:2, 1),
                                                          env = outcomes[[CurrentValues$game]][,1] + sample(-2:2, 1),
                                                          nTrials = ifelse(CurrentValues$page == "game", nTrials, nTrialsPractice),
                                                          game = CurrentValues$game,
                                                          goal = ifelse(CurrentValues$page == "game", goal, goal.practice)))
        
        return(
          list(
            # Main Display: Contains both a pump and a save button
            fixedRow(
              tags$script('newGame();'),
              column(12,
                     fixedRow(tags$br()),
                     fixedRow(column(12, align = "left", h2(ifelse(CurrentValues$game == 1, "Practice Game", paste("Game ", CurrentValues$game - 1, "of 10"))))),
                     fixedRow(
                       column(6, align="right", p(id = "clicksRemaining",
                                                   paste(ifelse(CurrentValues$page == "game", nTrials, nTrialsPractice)))),
                       column(6, align="left", h3(id = "clicksText", class = "upperParams", " Clicks Remaining"))
                     ),
                     fixedRow(
                       column(5, align="right", p(id = "pointCounter", "0")), # This is updated via JavaScript
                       column(1, align="left", p(id = "goalvalue", paste0("/", ifelse(CurrentValues$page == "game", goal, goal.practice)))),
                       column(6, align="left", h3(id = "pEarned", class = "upperParams", " Points Earned"))
                     ),
                     fixedRow(tags$br()),
                     fixedRow(
                       column(1, align="center",
                              HTML('<h1 id="emptySpace1" class="emptySpace">Place</h1>')),
                       column(5, align="center",
                              HTML('<h1 id="deck1" class="decks" onclick="updateValue(\'deck1\', \'deck2\', \'pointCounter\',
                                  \'clicksRemaining\', ens, eno, env, ent, ind, 1, outcome, outcomeCum, selection, nTrials, gameNr,
                                  respTime, trial, t, goal, clickEnabled)"> </h1>')),
                      # column(2, align="center",
                      #        HTML('<p id="emptySpace2" class="emptySpace">Place</p>')),
                      column(5, align="center",
                             HTML('<h1 id="deck2" class="decks" onclick="updateValue(\'deck2\', \'deck1\', \'pointCounter\',
                                  \'clicksRemaining\', env, ent, ens, eno, ind, 2, outcome, outcomeCum, selection, nTrials, gameNr, respTime,
                                  trial, t, goal, clickEnabled)"> </h1>')),
                      column(1, align="center",
                             HTML('<h1 id="emptySpace2" class="emptySpace">Place</h1>'))),

                     fixedRow(
                       column(6,
                              hidden(actionButton("continueGame", label = "Click to Continue to next Game",
                                                  style =  "margin-top: 2em; margin-left: 5.3em; margin-bottom: 3em" )),
                              offset =  4))))
            )
          )
      }

    # 6) POST PRACTICE GAME
    if (CurrentValues$page == "postPractice"){
      return(
        div(class = "gameInfo", checked = NA,
            list(
              tags$br(), tags$br(),
              h2("Finished with Practice Game", class = "firstRow"),
              p("You are now finished with the practice game. On the next pages, you'll start playing the first of 10 real games that will count towards your bonus!"),
              p("Here are a few additional notes and reminders about the game:"),
              tags$ul(
                tags$li("You will play 10 games in total. Your final bonus will be the sum of the bonuses you earn across all games. For example, if you end 3 games with at least 100 points, then you will earn a final bonus of 3 x 25 cents = 75 cents."),
                tags$li("The boxes are the same in each game. However, the", strong("locations of the boxes will be randomly determined"), "at the start of each game. The boxes might be in the same location, or different locations, in each game."),
                tags$li("The point values in the boxes", strong("do not change over time."), " Each time you choose an option, the point value you see is always returned to the box."),
                tags$li(strong("Remember, for each game that you earn at least 100 points you earn a bonus of 25 cents!"))
              ),
              p(strong("On the next page the first real game will start. Click to continue when you are ready.")),
              tags$br(),
              actionButton(inputId = "gt_game", 
                           label = "Start Game 1", class = "continueButtons") 
            )
        )
      )
    }
    
    # 4) END OF GAME PAGE
    if (CurrentValues$page == "pageEndGame") {
      return(
        div(class = "gameInfo", checked = NA,
            list(
              tags$br(), tags$br(),
              p(paste("You ended Game", CurrentValues$game - 2, "with", GameData$points.cum[length(GameData$points.cum)], "points.")),
              
              if (GameData$points.cum[length(GameData$points.cum)] >= goal){h3(paste("You did reach 100 points and earned a bonus of 25 cents for this game!"))},
              if (GameData$points.cum[length(GameData$points.cum)] < goal){h3(paste("You did not reach 100 points and did not earn a bonus for this game."))},
              if (GameData$points.cum[length(GameData$points.cum)] < goal){p("Remember that while you can increase your chances of reaching 100 points based on how you play the game, there is always a chance you won’t reach 100 points. Don’t get discouraged and try again in the next game.")},
              
              p("Click the button below to start the next game."),
              p("Remember that all games have the same boxes, however, the positions of the boxes will be randomly determined when the game starts."),
              tags$br(),
              actionButton(inputId = "gt_games", 
                           label = paste0("Start Game ", CurrentValues$game - 1), class = "continueButtons"))))
    }
    
    if (CurrentValues$page == "lastEndGame") {
      
      return(
        div(class = "gameInfo", checked = NA,
            list(
              tags$br(), tags$br(),
              h3("You finished all games!", class = "firstRow"),
              p(strong(paste0("You have now finished playing all 10 games. You reached 100 points ", CurrentValues$nGoalsReached, " times."), br(), paste0("Thus you receive a bonus of ", CurrentValues$nGoalsReached, " x 25 cents, that is $", CurrentValues$payout, "."))),
              tags$br(),
              h3("Please answer the following question about the two options."),
              radioButtons("which.high.ev",
                           label = "You may have noticed that in each game, there was one option with a larger variability of outcomes, and one option with a smaller variability. Do you think one of these options had, on average, better points than the other?",
                           choices = list("I think the option with the higher point variability also had higher values on average." = 1,
                                          "I think the option with the lower point variability had higher values on average." = 2,
                                          "I think both options gave the same number of points on average." = 3),
                           selected = character(0),
                           width = "800px"),
              tags$br(),
              disabled(actionButton(inputId = "gt_part2Inst", 
                           label = "Continue", class = "continueButtons")))))
    }
    
    if (CurrentValues$page == "part2Inst") {
      
      return(
        div(class = "inst", checked = NA,
            list(
              tags$br(), tags$br(),
              h3("Study Part 2", class = "firstRow"),
              p("You will now complete a few surveys about the game and how you make decisions in general."),
              p("Your answers to all future questions will not affect your bonus. However, please make sure to complete the rest of the survey for your work and bonus to be accepted."),
              p("Click on \"Continue\" to  start with the second part of the study. You will have to enter your workerid again on the next page."),
              tags$br(),
              actionButton(inputId = "gt_Questionnaire", 
                           label = "Continue", class = "continueButtons", onclick =linkPage))))
    }
    
  })
  
  
  
  # --------------------------------
  # Section E: Event (e.g.; button) actions ----
  # --------------------------------
  
  # Section F1: Page Navigation Buttons
  observeEvent(input$gt_inst1, {
    if (gsub("[[:space:]]", "", tolower(as.character(input$workerid))) %in% tolower(ids.df[, 1])){
      CurrentValues$checkOk <- 1
      CurrentValues$page <- "notAllowed"
    } else {
      CurrentValues$checkOk <- 2
      CurrentValues$page <- "inst1"
    }
  })
  observeEvent(input$gt_inst2, {CurrentValues$page <- "inst2"})
  observeEvent(input$gt_goalInst, {CurrentValues$page <- "goalInst"})
  observeEvent(input$gt_instCheck, {CurrentValues$page <- "instCheck"})
  observeEvent(input$gt_inst3, {
    if (!is.null(input$checkGoal)){
      if (input$checkChange == 2 & input$checkGoal == 1) {
        CurrentValues$page <- "inst3"
      } else {
        CurrentValues$page <- "failedCheck"
        CurrentValues$checkFails <- CurrentValues$checkFails + 1
        # updateRadioButtons(session, "checkChange", selected = character(0))
      }
    }
  })
  observeEvent(input$gt_practicegame, {CurrentValues$page <- "practicegame"})
  observeEvent(input$continueGame, {
    if (CurrentValues$game == 1){
      CurrentValues$page <- "postPractice"
    } else { if (CurrentValues$game %in% c(2:(n.games - 1))){
      CurrentValues$page <- "pageEndGame"
    } else {
      CurrentValues$payout <- CurrentValues$nGoalsReached * .25
      CurrentValues$page <- "lastEndGame"
    }
    }
    
    CurrentValues$game <- unique(GameData$game)[length(unique(GameData$game))] + 1
    
    })
  observeEvent(input$gt_game, {CurrentValues$page <- "game"})
  observeEvent(input$gt_games, {CurrentValues$page <- "game"})

  # Section F2: Event tracking buttons

  observeEvent(input$gameNr,{
    if (length(input$gameNr == CurrentValues$game) == ifelse(CurrentValues$game == 1, nTrialsPractice , nTrials)){
      index <- (length(input$trial) - length(input$gameNr == CurrentValues$game)) : length(input$trial)
      toggle("continueGame")
      GameData$trial <- c(GameData$trial, input$trial[index])
      GameData$time <- c(GameData$time, input$respTime[index])
      GameData$selection <- c(GameData$selection, input$selection[index])
      GameData$outcome <- c(GameData$outcome, input$outcome[index])
      GameData$points.cum <- c(GameData$points.cum, input$outcomeCum[index])
      GameData$game <- c(GameData$game, input$gameNr[index])
      if (input$outcomeCum[length(input$outcomeCum)] >= goal){
        CurrentValues$nGoalsReached <- CurrentValues$nGoalsReached + 1
      }
    }
  })
  
  # observeEvent(input$checkChange, {
  #   enable("gt_inst3")
  # })
  
  observeEvent(input$which.high.ev, {
    enable("gt_part2Inst")
  })

  
  # --------------------------------
  # Section F: Save data ---- Commented out for now
  # --------------------------------
  observeEvent(input$gt_part2Inst, {
    
    # Create progress message
    withProgress(message = "Saving data...",
                 value = 0, {
                   
                   incProgress(.25)
                   
                   GameData.i <- data.frame("trial" = GameData$trial,
                                            "time" = GameData$time,
                                            "selection" = GameData$selection, 
                                            "outcome" = GameData$outcome,
                                            "game" = GameData$game,
                                            "points.cum" = GameData$points.cum,
                                            "option.order" = option.order,
                                            "workerid" = input$workerid,
                                            "goal" = goal,
                                            "condition" = condition,
                                            "n.goals.reached" = CurrentValues$nGoalsReached,
                                            "checkFails" = CurrentValues$checkFails,
                                            "payout" = CurrentValues$payout,
                                            "which.high.ev" = input$which.high.ev)
                   
                   
                   incProgress(.5)
                   
                   GameDatafileName <- paste0(input$workerid, as.integer(Sys.time()), digest::digest(GameData.i), "_g.csv")
                   GameDatafilePath <- file.path(tempdir(), GameDatafileName)
                   write.csv(GameData.i, GameDatafilePath, row.names = FALSE, quote = TRUE)
                   rdrop2::drop_upload(GameDatafilePath, 
                                       dest = outputDir, 
                                       dtoken = EPtoken)
                   
                   CurrentValues$page <- "part2Inst"
                   Sys.sleep(.25)
                   incProgress(1)
                   
                 })
    
  })
  
  observe({
    
    # Check if input was given and enable and disable the continue button
    if(CurrentValues$page == "welcome"){
      
      if(!is.null(input$workerid)){
        
        if(nchar(as.character(input$workerid)) > 4){
          
          enable("gt_inst1")
          
        }
      }
    }
    
    if(CurrentValues$page == "inst1"){
      onlyID <- data.frame("workerID" = input$workerid)
      # Write survey data 
      IDDatafileName <- paste0(input$workerid, as.integer(Sys.time()), digest::digest(onlyID), "_g.csv")
      IDDatafilePath <- file.path(tempdir(), IDDatafileName)
      write.csv(onlyID, IDDatafilePath, row.names = FALSE, quote = TRUE)
      rdrop2::drop_upload(IDDatafilePath, dest = idDir, dtoken = EPtoken)
      
    }
  })
  
}

# Create app!
shinyApp(ui = ui, server = server)
