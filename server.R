library(shiny)
library(tidyverse)
library(jsonlite)
library(anytime)
library(dplyr)

shinyServer(function(input, output) {
source("./functions.R")

#==========PRE CLEANING INPUTS==================================================

#maximum 5 ids to compare/ hard coded
#So this code is going through and adding one extra Doenet ID entry box
# for each one requested in input$numid. If (for example) you only request
# two, then the remaining 3 output IDs will be set to NULL and not shown
# It feels like we could accomplish this with a loop, but after multiple
# attempts, none of us have been successful.
output$rid <-
  renderUI({
    i = 1
    j = input$numid
    if (i <= j) {
      output$id1 <- renderUI({
        textInput("id1", "Doenet ID 1")
      })
      i = i + 1
    } else{
      output$id1 = NULL
    }
    if (i <= j) {
      output$id2 <- renderUI({
        textInput("id2", "Doenet ID 2")
      })
      i = i + 1
    } else{
      output$id2 = NULL
    }
    if (i <= j) {
      output$id3 <- renderUI({
        textInput("id3", "Doenet ID 3")
      })
      i = i + 1
    } else{
      output$id3 = NULL
    }
    if (i <= j) {
      output$id4 <- renderUI({
        textInput("id4", "Doenet ID 4")
      })
      i = i + 1
    } else{
      output$id4 = NULL
    }
    if (i <= j) {
      output$id5 <- renderUI({
        textInput("id5", "Doenet ID 5")
      })
      i = i + 1
    } else{
      output$id5 = NULL
    }
  })


#Slider for time in the time plots
output$time_slider <-
  renderUI({
    sliderInput(
      "maxtime",
      min = 0,
      "Maximum time shown:",
      max = input$maxtime_set,
      value =  c(500, 10000)
    )
    
  })

#These next two lines pull data directly from events (before it is cleaned)
# that is crucial to determining the date and version selection on the sidebar.
# As a rule we have typically tried to avoid working on events directly, but 
# because this determines how we clean we have made an exception.
dates <- reactive(pull_dates(events()))
versions <- reactive(pull_versions(events()))

#This outputs the version selection and the date slider for the UI
output$version_select = renderUI({ selectInput("version_selected", "Version: ", c(1:versions()))})
output$date_slider = renderUI({sliderInput("date_range", "Data from: ", 
                                           min = min(dates()), 
                                           max = max(dates()), 
                                           value = c(
                                             min(dates()),
                                             max(dates())
                                           )
)
})

#==========================GETTING DATA=========================================
# What this code is doing is pulling in the data
# getQueryString() is a function that takes a query string and turns it into
# a list, which allows us to find the "data" item of that list.
# By default it pulls the query string from the app environment (?)
# renderText turns it that list into a string and then checks if it is null
# This is a check to make sure we are in fact looking for data that exists

#Stream_in unpacks the json file we get from the URL into a 1 by 3 dataframe
#First element is a boolean that tells if it was successful or not
#Second element is a message (typically empty right now)
#Third is the list that contains the event log
#df contains this 1 by 3 frame at the end of this block
df <- eventReactive(input$submit_extra | input$update, {
  if (input$submit_extra != 0) {
    
    end_of_link = paste0(
      "&doenetId[]=",
      input$id1,
      "&doenetId[]=",
      input$id2,
      "&doenetId[]=",
      input$id3,
      "&doenetId[]=",
      input$id4,
      "&doenetId[]=",
      input$id5
    )

  }
  else{
    end_of_link = ""
  }
  stream_in(file(
    paste0(
      "https://www.doenet.org/api/getEventData.php?doenetId[]=",
      #"_YImZRcgrUqyNBLHd0tbP2" # for debugging to have a set doenetid to use
      getQueryString()[["data"]],
      end_of_link
    )
  ))
})

#=================================PROCESSING DATA===============================
#This block pulls out the events log, which is a dataframe, within a
# 1 element list within a 1 by 3 dataframe. So df is the frame,
# events is an named column of df, which contains one element, which is a
# dataframe containing the events log, which we are then assigning to a local
# variable called events. Note the difference between the events column of df
# and our local events object (even though they are essentially the same data)

events <- reactive({
  df()$events[[1]]
})
  
# Takes our events and cleans them up and adds some helpful columns
# See file functions.R for more information.

#A note on how data is currently structured:
# There are four working sets:
# cleaned_version -> all the way cleaned except including data from all versions
#                    of the activity (needed for version comparison)
# summary_data_version -> summary of the cleaned_version set by problem
#                         needed to do version by version by problem comparisons
# cleaned -> the true cleaned data, which is cleaned filtered to look at the 
#             selected version. This is used for all non-cross-version plots.
#             For more on this filter system, please consult functions.R
# summary_data -> summary data by problem from cleaned, only looking at one version.
#                 Used to do problem by problem work when not looking across versions.



#Input from date slider determines which dates are included in the set.
cleaned_version <- reactive({
clean_events(events(),input$date_range[1],input$date_range[2]) 
})

summary_data_version <- reactive({summarize_events(cleaned_version())})

#Filter takes in previously cleaned data and then the version we select
cleaned = reactive({version_filter(cleaned_version(), input$version_selected)})

summary_data = reactive({summarize_events(cleaned())})
    
#=========================DOWNLOADING DATA======================================
#This gives allows the user to download the data shown in a csv file for their
#own purposes
output$downloadData <- downloadHandler(
  filename = function() {
    paste('events-', Sys.Date(), '.csv', sep = '')
  },
  content = function(file) {
    write.csv(events(), file)
  }
)

#=========================DATA TABLES===========================================
# creates a table of cleaned data
output$cleaned_data_w_versions <- renderDataTable(cleaned_version())

# creates a table of raw data
output$raw <- renderDataTable(events())

# This renders the summary data in a table
output$summary <- renderDataTable(summary_data())

#=======================SUMMARY TEXT============================================
#creates an output text detailing how many students in the data set
output$num_students <-
  renderText(paste0(
    "There is/are ",
    n_distinct(events()$userId, na.rm = TRUE),
    " student(s)"
  ))
#creates an output text detailing how many versions are present in the set
output$num_versions <- renderText(paste0("There are ",versions() ))

#creates an output text detailing how many different doenet experiments
#are represented in this set.
output$num_doenetIds <-
  renderText(paste0(
    "There is/are ",
    n_distinct(events()$doenetId, na.rm = TRUE),
    " doenetId(s)"
  ))
#creates an output text detailing how many pages are included in this dataset
output$num_pages <-
  renderText(paste0(
    "There is/are ",
    n_distinct(summary_data_version()$pageNumber, na.rm = TRUE),
    " page(s)"
  ))

#=============================GENERAL PLOTS=====================================
#This is a plot that shows time to credit for each problem
output$time_plot <- renderPlot({
  cleaned() %>%
    filter(!is.na(itemCreditAchieved)) %>% 
    ggplot(aes(y = itemCreditAchieved, x = time, color=userId))+
    geom_line()+
    theme(legend.position = "none")+
    facet_wrap(~pageNumber)+
    labs(x = "Time", y = "Total Credit on Page")+
    xlim(input$maxtime[1],input$maxtime[2])
})
#This is the time plot from the start (start point in time is always 0)
output$time_plot_s <- renderPlot({
cleaned() %>%
    filter(!is.na(itemCreditAchieved)) %>% 
    ggplot(aes(y = itemCreditAchieved, x =time, color=userId))+
    geom_line()+
    theme(legend.position = "none")+
    facet_wrap(~pageNumber)+
    labs(x = "Time", y = "Total Credit on Page")+
    xlim(0,input$maxtime[2])
})

#This displays a series of histograms for scores on each problem on each page
output$hist_prob <- renderPlot(
  #bins = nrow(distinct(summary_data() , score))
  summary_data() %>%
    ggplot(aes(x = score)) +
    geom_histogram( ) +
    facet_grid(pageNumber ~ problem) +
    labs(x = "Score on Problem", y = "Count", title = "Breakdown by Problem")
)
#This displays a histogram of overall scores on the activity
#bins = nrow(distinct())
output$hist_total <- renderPlot(
  summary_data() %>%
    group_by(userId) %>%
    mutate(total = sum(score)) %>%
    ggplot(aes(x = total)) +
    geom_histogram() +
    labs(x = "Total Points", y = "Number of Students", title = "Total Scores on Assignment")
)

#========================ATTEMPT BASED PLOTS====================================
#This displays a plot of average submissions per question    
output$hist_submissions <- renderPlot({
  submitted_data <- function(){cleaned()[cleaned()$verb=="submitted",]}
  totals <- table(submitted_data()$componentName)/n_distinct(events()$userId, na.rm = TRUE)
  ggplot(as.data.frame(totals), aes(x=Var1, y=Freq)) +
    geom_bar(stat="identity") +
    labs(x="Question", y="Submissions", title = "Average Number of Submissions per Question")
})

#This displays a plot of the submission percentiles for a specific question
output$q_submissions <- renderPlot({
  q_data <- function(){cleaned()[cleaned()$verb=="submitted" &
                                 cleaned()$componentName==input$subm_q,]}
  n_subm_by_id <- table(q_data()$userId) %>% as.data.frame()
  ggplot(n_subm_by_id, aes(x=Freq)) +
    geom_bar(stat="count") +
    labs(x="Number of Submissions", y="Number of Students", title = "Distribution of Submissions")
})

#This displays a plot of how the submissions are distributed across attempts
output$hist_subm_attempt <- renderPlot({
  submitted_data <- function(){cleaned()[cleaned()$verb=="submitted",]}
  ggplot(submitted_data(), aes(x=componentName)) +
    geom_bar(aes(fill=attemptNumber)) + 
    labs(x="Question", y="Number of Submissions", title="Number of Submissions Across Attemtps")

})
   
#====================WRONG ANSWER BASED PLOTS===================================
#From here down is wrong answer code
output$wrong_plot <- renderPlot({
  summary_data() %>% 
    group_by(problem) %>% 
    filter(creditAchieved < 1) %>% 
    ggplot(aes(x = as.factor(response), y = n,fill = as.factor(response))) + 
    geom_col()+facet_wrap(~problem)
})

#================VERSION COMPARISON PLOTS=======================================

#This one just does a bar graph of average score for each question
output$problem_avgs_version <- renderPlot({

  summary_data_version() %>% 
  group_by(version_num) %>%
  #arrange(avg) %>%
  ggplot(aes(x = problem, y = avg,fill = as.factor(version_num))) +
  geom_col( stat = "identity", position = 'dodge') +
  labs(x = "problem", y = "average score", title = "average score by problem by version")+
    #guides(fill=guide_legend(title="Version")) +
  ylim(c(0,1))
  
})
#This is time plots faceted by version
output$time_plot_version <- renderPlot({
  cleaned_version() %>%
    filter(!is.na(itemCreditAchieved)) %>% 
    group_by(version_num) %>%
    ggplot(aes(y = itemCreditAchieved, x = time, color=userId))+
    geom_line()+
    theme(legend.position = "none")+
    facet_grid(version_num~pageNumber)+
    labs(x = "Time", y = "Total Credit on Page")+
    xlim(input$maxtime[1],input$maxtime[2])
})
#Timeplot from start, again, faceted by version
output$time_plot_s_version <- renderPlot({
  cleaned_version() %>%
    group_by(version_num) %>% 
    filter(!is.na(itemCreditAchieved)) %>% 
    ggplot(aes(y = itemCreditAchieved, x =time, color=userId))+
    geom_line()+
    theme(legend.position = "none")+
    facet_grid(version_num~pageNumber)+
    labs(x = "Time", y = "Total Credit on Page")+
    xlim(0,input$maxtime[2])
})
#histogram of total scores faceted by version
#bins = nrow(distinct(summary_data() , score))
output$hist_total_version <- renderPlot(
  summary_data_version() %>%
    group_by(userId,version_num) %>%
    summarize(total = sum(score)) %>%
    ggplot(aes(x = total)) +
    geom_histogram() +
    labs(x = "Total Points", y = "Number of Students", title = "Total Scores on Assignment")
  +facet_wrap(~version_num) 
                                                  
)
  
})
