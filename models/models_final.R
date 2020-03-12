library(gdata) #excel files
library(openxlsx) #excel files
library(lubridate) #dates
library(data.table)
library(lme4) #mixed effects models

# NOTE: CODE FOR DATA EXPLORATION AND RESULTS WAS REMOVED 
# FOR BREVITY

# THERE ARE TWO SOURCES OF DATA:
# 1) TEAM SHOTS (source: WhoScored)
# season-level team stats e.g. shots/goals from penalty area
# 2) GAME STATS (source: FootyStats)
# game-level stats e.g. possession, shots on target, goals

# 1)
# DATA PREPARATION
# flatten spreadsheet with multiple tabs into single spreadsheet
# with standardized column names
file="../data/whoscored_shots_d.xlsx"
pat="\\bTeam.+|\\bR\\b|\\bRating.+|\\bTotal.*"
sheetnames = c("2009-10", "2010-11", "2011-12", "2012-13", 
               "2013-14","2014-15", "2015-16", "2016-17", 
               "2017-18", "2018-19")
for(f in sheetnames) {
  ss <- read.xls(file, sheet=f)
  ss <- ss[,-grep(pat, colnames(ss))]
  # aggregate
  ss_total <- ss[c(1:20),]
  ss_total$season <- f
  names(ss_total) <- tolower(names(ss_total))
  names(ss_total) <- c("team", "shots_outofbox", "shots_sixyardbox",
             "shots_penaltyarea", "rating", "shots_openplay",
             "shots_counter", "shots_setpiece", "shots_penaltytaken",
             "shots_offtarget", "shots_onpost", "shots_ontarget",
             "shots_blocked", "shots_rightfoot", "shots_leftfoot",
             "shots_head", "shots_other", "goals_sixyardbox",
             "goals_penaltyarea", "goals_outofbox", "goals_openplay",
             "goals_counter", "goals_setpiece", "goals_penaltyscored",
             "goals_own", "goals_normal", "goals_rightfoot",
             "goals_leftfoot", "goals_head", "goals_other", "season"
             )
  ss_total <- ss_total[,c(1,31,5,2,3,4,6,7,8,9,10,11,12,13,14,15,16,17,18,19,
                      20,21,22,23,24,25,26,27,28,29,30)]
  # home
  ss_home <- ss[c(22:41),]
  names(ss_home) <- tolower(names(ss_home))
  names(ss_home) <- c("team", "shots_outofbox", "shots_sixyardbox",
               "shots_penaltyarea", "rating", "shots_openplay",
               "shots_counter", "shots_setpiece", "shots_penaltytaken",
               "shots_offtarget", "shots_onpost", "shots_ontarget",
               "shots_blocked", "shots_rightfoot", "shots_leftfoot",
               "shots_head", "shots_other", "goals_sixyardbox",
               "goals_penaltyarea", "goals_outofbox", "goals_openplay",
               "goals_counter", "goals_setpiece", "goals_penaltyscored",
               "goals_own", "goals_normal", "goals_rightfoot",
               "goals_leftfoot", "goals_head", "goals_other"
               )
  ss_home <- ss_home[,c(1,5,2,3,4,6,7,8,9,10,11,12,13,14,15,16,17,18,19,
                        20,21,22,23,24,25,26,27,28,29,30)]
  for (n in length(names(ss_home))){
    names(ss_home) <- paste(names(ss_home), "home", sep="_")
  }
  # away
  ss_away <- ss[c(43:62),]
  names(ss_away) <- tolower(names(ss_away))
  names(ss_away) <- c("team", "shots_outofbox", "shots_sixyardbox",
               "shots_penaltyarea", "rating", "shots_openplay",
               "shots_counter", "shots_setpiece", "shots_penaltytaken",
               "shots_offtarget", "shots_onpost", "shots_ontarget",
               "shots_blocked", "shots_rightfoot", "shots_leftfoot",
               "shots_head", "shots_other", "goals_sixyardbox",
               "goals_penaltyarea", "goals_outofbox", "goals_openplay",
               "goals_counter", "goals_setpiece", "goals_penaltyscored",
               "goals_own", "goals_normal", "goals_rightfoot",
               "goals_leftfoot", "goals_head", "goals_other"
               )
  ss_away <- ss_away[,c(1,5,2,3,4,6,7,8,9,10,11,12,13,14,15,16,17,18,19,
                        20,21,22,23,24,25,26,27,28,29,30)]
  for (n in length(names(ss_away))){
    names(ss_away) <- paste(names(ss_away), "away", sep="_")
  }
  ss <- cbind(ss_total,ss_home,ss_away)
  ss <- ss[, -grep("team_.+|rating_.+", names(ss))]
  if (file.exists("ss") == FALSE){
    saveRDS(ss, "ss")
  } else {
    ss_old <- readRDS("ss")
    ss_new <- rbind(ss_old, ss)
    saveRDS(ss_new, "ss")
    }
}
ss_final <- readRDS("ss")
# write.csv(ss_final, "../data/whoscored_shots_clean.csv", row.names=FALSE)

# DATA PRE-PROCESSING
xg <- read.csv("../data/whoscored_shots_clean.csv")

# remove penalties and own goals
xg$total_goals <- xg$goals_outofbox + xg$goals_penaltyarea +
  xg$goals_sixyardbox - xg$goals_penaltyscored - xg$goals_own
xg$total_goals_home <- xg$goals_outofbox_home + xg$goals_penaltyarea_home +
  xg$goals_sixyardbox_home - xg$goals_penaltyscored_home - xg$goals_own_home
xg$total_goals_away <- xg$goals_outofbox_away + xg$goals_penaltyarea_away +
  xg$goals_sixyardbox_away - xg$goals_penaltyscored_away - xg$goals_own_away

# remove penalties from shots taken from penalty area
xg$shots_penaltyarea_home_np <- xg$shots_penaltyarea_home - xg$shots_penaltytaken_home
xg$shots_penaltyarea_away_np <- xg$shots_penaltyarea_away - xg$shots_penaltytaken_away

xg_ss <- xg[,c(1:2, 88, 4:9, 15:18)]
names(xg_ss) <- c("Team", "Season", "Total Goals", "Shots OutofBox", 
                  "Shots Six Yard Box","Shots Penalty Area","Shots Open Play",
                  "Shots Counter","Shots Set Piece","Shots Right Foot",
                  "Shots Left Foot","Shots Header","Shots Other")

# 2)
# DATA PREPARATION
path1 = "../data/england-premier-league-matches"
path2 = "stats.csv"

games1 <- read.csv(paste(path1,"2007-to-2008",path2,sep="-"))
games2 <- read.csv(paste(path1,"2008-to-2009",path2,sep="-"))
games3 <- read.csv(paste(path1,"2009-to-2010",path2,sep="-"))
games4 <- read.csv(paste(path1,"2010-to-2011",path2,sep="-"))
games5 <- read.csv(paste(path1,"2011-to-2012",path2,sep="-"))
games6 <- read.csv(paste(path1,"2012-to-2013",path2,sep="-"))
games7 <- read.csv(paste(path1,"2013-to-2014",path2,sep="-"))
games8 <- read.csv(paste(path1,"2014-to-2015",path2,sep="-"))
games9 <- read.csv(paste(path1,"2015-to-2016",path2,sep="-"))
games10 <- read.csv(paste(path1,"2016-to-2017",path2,sep="-"))
games11 <- read.csv(paste(path1,"2017-to-2018",path2,sep="-"))
games12 <- read.csv(paste(path1,"2018-to-2019",path2,sep="-"))
games13 <- read.csv(paste(path1,"2019-to-2020",path2,sep="-"))

games <- do.call("rbind",list(games1,games2,games3,games4,games5,
                              games6,games7,games8,games9,games10,
                              games11,games12,games13))

games <- games[,1:35]
names(games) <- c("timestamp", "date", "status", "attendance", "away_team",
                  "home_team","prematch_ppg_home", "prematch_ppg_away",
                  "home_ppg", "away_ppg","home_ftgoals", "away_ftgoals",
                  "total_ftgoals", "total_htgoals", "home_htgoals",
                  "away_htgoals", "home_goal_times", "away_goal_times",
                  "home_corners", "away_corners", "home_yellows", "home_reds",
                  "away_yellows", "away_reds", "home_shots", "away_shots",
                  "home_shots_ontarget", "away_shots_ontarget",
                  "home_shots_offtarget", "away_shots_offtarget","home_fouls",
                  "away_fouls", "home_possession", "away_possession",
                  "prematch_avg_gpg")

games$evening <- ifelse(games$time > "7:00pm", 1, 0)

games$ft_result_home <- ifelse(games$home_ftgoals > games$away_ftgoals,1,0)
table(games$ft_result_home)

# DATA PRE-PROCESSING
# fix dates
games$time <- tstrsplit(as.character(games$date), " - ")[[2]]
games$date <- tstrsplit(as.character(games$date), " - ")[[1]]

games$date_mdy <- as.Date(parse_date_time(games$date, orders=c("mdy")))

games$month <- as.numeric(substr(games$date_mdy,6,7))
games$year <- as.numeric(substr(games$date_mdy,1,4))

# split into seasons
games$season <- ifelse(games$month < 8, games$year - 1, games$year)
games$season <- paste(games$season,substr(games$season+1,3,4),sep="-")
games$season <- as.factor(games$season)

# remove 2010-11 and 2011-12 season because of missing data
games <- games[!(games$away_corners < 0),]

games_ss <- games[,c("date_mdy", "season","home_team", "away_team",
                  "prematch_ppg_home", "prematch_ppg_away",
                  "home_ftgoals","away_ftgoals","home_corners", 
                  "away_corners", "home_yellows","away_yellows",
                  "home_reds", "away_reds","home_shots_ontarget",
                  "away_shots_ontarget","home_fouls","away_fouls",
                  "home_possession", "ft_result_home")]
names(games_ss) <- c("date", "season", "ht", "at","h-ppg", "a-ppg", 
                     "hg","ag", "hc","ac", "hy", "ay","hr", "ar",
                     "hst","ast","hf","af", "hp", "o")
rownames(games_ss) <- NULL
# write.csv(games, "../data/footystats_games.csv", row.names=FALSE)

# MODELING EXPECTED GOALS (xG)
# linear random-intercept model 1: zonal
hmod_xg1 <- lmer(total_goals ~ (1 | team) + season + 
                   shots_outofbox_home + shots_sixyardbox_home +
                   shots_penaltyarea_home + shots_outofbox_away +
                   shots_sixyardbox_away + shots_penaltyarea_away,
                 data=xg)

# penaltyarea:outofbox (170% higher)
# outofbox:penaltyarea (140% higher)
fixef(hmod_xg1)["shots_penaltyarea_home"]/fixef(hmod_xg1)["shots_outofbox_home"]
fixef(hmod_xg1)["shots_sixyardbox_home"]/fixef(hmod_xg1)["shots_penaltyarea_home"]

# penaltyarea:outofbox (900% higher)
# outofbox:penaltyarea (25% higher)
fixef(hmod_xg1)["shots_penaltyarea_away"]/fixef(hmod_xg1)["shots_outofbox_away"]
fixef(hmod_xg1)["shots_sixyardbox_away"]/fixef(hmod_xg1)["shots_penaltyarea_away"]

# linear random-intercept model 2: situational
hmod_xg2 <- lmer(total_goals ~ (1 | team) + season + shots_openplay_home +
                   shots_counter_home + shots_setpiece_home +
                   shots_openplay_away + shots_counter_away +
                   shots_setpiece_away, data=xg)

# linear random-intercept model 3: physical
hmod_xg3 <- lmer(total_goals ~ (1 | team) + season + shots_leftfoot_home +
                    shots_rightfoot_home + shots_head_home + 
                    shots_other_home + shots_leftfoot_away +
                    shots_rightfoot_away + shots_head_away + 
                    shots_other_away, data=xg)

results <- data.frame("xg1"=predict(hmod_xg1),
                      "xg2"=predict(hmod_xg2),
                      "xg3"=predict(hmod_xg3))
results <- cbind(xg[,c("team", "season")], results)
results$season_next <- paste(as.numeric(substr(results$season,1,4))+1,
                             as.numeric(substr(results$season,6,7))+1,
                             sep="-")
results$season_next <- as.factor(results$season_next)
# total games in a season = 38
results[,3:5] <- results[,3:5]/38

# standardize team names
results$team <- plyr::mapvalues(results$team, 
from=c("Tottenham", "Birmingham","West Ham", "Bolton", "Stoke", "Wigan", "Blackburn", "Hull", "Swansea", "Norwich", "Cardiff", "Leicester", "Bournemouth", "Brighton", "Huddersfield"),
to=c("Tottenham Hotspur", "Birmingham City", "West Ham United", "Bolton Wanderers", "Stoke City", "Wigan Athletic", "Blackburn Rovers", "Hull City", "Swansea City", "Norwich City", "Cardiff City", "Leicester City", "AFC Bournemouth", "Brighton & Hove Albion", "Huddersfield Town"))

games <- merge(games, results, by.x=c("home_team", "season"),
               by.y=c("team", "season_next"), all.x=TRUE)
games$season.y <- NULL
names(games) <- plyr::mapvalues(names(games), 
                                from=c("xg1", "xg2", "xg3"),
                                to=c("xg1_home", "xg2_home", 
                                     "xg3_home"))
# TEST
# xg not available for season_next if team was relegated in season
# summary(games[is.na(games$xg1_home),c("home_team")])

games <- merge(games, results, by.x=c("away_team", "season"), 
               by.y=c("team", "season_next"), all.x=TRUE)
games$season.y <- NULL
names(games) <- plyr::mapvalues(names(games), 
                                from=c("xg1", "xg2", "xg3"),
                                to=c("xg1_away", "xg2_away", 
                                     "xg3_away"))
# TEST
# summary(games[is.na(games$xg1_away),c("away_team")])

# drop games with missing xG's
games <- games[!(is.na(games$xg1_home) | is.na(games$xg1_away)),]

# MODELING ODDS OF WINNING
# odds model 1: zonal
lreg_odds1 <- glm(ft_result_home ~ home_corners +
                      away_corners + home_fouls + away_fouls + home_reds +
                      away_reds + home_yellows + away_yellows +
                      home_shots_ontarget + away_shots_ontarget + 
                      prematch_ppg_home + prematch_ppg_away + 
                      home_possession + xg1_home + xg1_away,
                  family=binomial(link="logit"), data=games)

# odds model 2: physical
lreg_odds2 <- glm(ft_result_home ~ home_corners +
                      away_corners + home_fouls + away_fouls + home_reds +
                      away_reds + home_yellows + away_yellows +
                      home_shots_ontarget + away_shots_ontarget + 
                      prematch_ppg_home + prematch_ppg_away + 
                      home_possession + xg2_home + xg2_away, 
                  family=binomial(link="logit"), data=games)

# odds model 3: situational
lreg_odds3 <- glm(ft_result_home ~ home_corners +
                      away_corners + home_fouls + away_fouls + home_reds +
                      away_reds + home_yellows + away_yellows +
                      home_shots_ontarget + away_shots_ontarget + 
                      prematch_ppg_home + prematch_ppg_away + 
                      home_possession + xg3_home + xg3_away,
                  family=binomial(link="logit"), data=games)