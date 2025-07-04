library("shiny")
library("DiagrammeR")

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      .green-box {
        background-color: YellowGreen;
        color: black;
        border-radius: 10px;
        padding: 10px;
        margin-bottom: 10px;}
      .green-box h4 {
        font-weight: bold;}"))),
  
  titlePanel("Shiny Virtual Factory"),
  
  sidebarLayout(
    sidebarPanel(
      actionButton("make_part", "Make a Part"),
      actionButton("copy_scratch", "Copy to Scratch Pad"),
      actionButton("clear_scratch", "Clear Scratch Pad"),
      numericInput("num_samples", "# of Samples", value = 0, min = 0, step = 1),
      selectInput("choose_rougher", "Choose Rougher", choices = c("Rougher Turn #1", "Rougher Turn #2", "Rougher Turn #3")),
      textOutput("supplier_output"),
      textOutput("rougher_output"),
      textOutput("finisher_output")),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Process",
                 tableOutput("part_history"),
                 downloadButton("download_history", "Export to CSV"),
                 fluidRow(
                   column(4, div(class = "green-box", h4("Supplier Material"), verbatimTextOutput("supplier_material"))),
                   column(4, div(class = "green-box", h4("Rougher Turn"), verbatimTextOutput("rougher_turn"))),
                   column(4, div(class = "green-box", h4("Finish Turn"), verbatimTextOutput("finish_turn"))))),
        
        tabPanel("Settings",
                 numericInput("supplier_mean", "Supplier Mean", value = 1250, min = 1000, max = 1500),
                 numericInput("supplier_sd", "Supplier Standard Deviation", value = 50),
                 numericInput("rougher_multiplier", "Rougher Multiplier", value = 0.95, min = 0.5, max = 0.95, step = 0.01),
                 numericInput("rougher_noise_sd", "Rougher Noise SD", value = 10),
                 numericInput("finisher_subtract_mean", "Finisher Subtract Mean", value = 200, min = 100, max = 300),
                 numericInput("finisher_subtract_sd", "Finisher Subtract SD", value = 50)),
        
        tabPanel("Diagram",
                 grVizOutput("diagram"))))))

server <- function(input, output, session) {
  process_data <- reactiveValues(
    supplier = NULL,
    rougher = NULL,
    finisher = NULL,
    history = data.frame(Supplier = numeric(), Rougher = numeric(), Finisher = numeric(), RougherNumber = character()))
  
  observeEvent(input$make_part, {
    supplier_material <- rnorm(1, mean = input$supplier_mean, sd = input$supplier_sd)
    process_data$supplier <- min(max(supplier_material, 1000), 1500)
    
    rougher_output <- process_data$supplier * input$rougher_multiplier + rnorm(1, mean = 0, sd = input$rougher_noise_sd)
    process_data$rougher <- rougher_output
    
    finish_output <- rougher_output - rnorm(1, mean = input$finisher_subtract_mean, sd = input$finisher_subtract_sd)
    process_data$finisher <- finish_output
    
    updateNumericInput(session, "num_samples", value = input$num_samples + 1)})
  
  observeEvent(input$copy_scratch, {
    new_entry <- data.frame(
      Supplier = round(process_data$supplier, 3),
      Rougher = round(process_data$rougher, 3),
      Finisher = round(process_data$finisher, 3),
      RougherNumber = input$choose_rougher)
    process_data$history <- rbind(process_data$history, new_entry)})
  
  observeEvent(input$clear_scratch, {
    process_data$history <- data.frame(Supplier = numeric(), Rougher = numeric(), Finisher = numeric(), RougherNumber = character())
    updateNumericInput(session, "num_samples", value = 0)})
  
  output$supplier_material <- renderText({
    if (is.null(process_data$supplier)) return("—")
    round(process_data$supplier, 3)})
  
  output$rougher_turn <- renderText({
    if (is.null(process_data$rougher)) return("—")
    round(process_data$rougher, 3)})
  
  output$finish_turn <- renderText({
    if (is.null(process_data$finisher)) return("—")
    round(process_data$finisher, 3)})
  
  output$part_history <- renderTable({
    process_data$history})
  
  output$download_history <- downloadHandler(
    filename = function() {
      paste("part_history_", Sys.Date(), ".csv", sep = "")},
    content = function(file) {
      write.table(process_data$history, file, sep = ";", dec = ",", row.names = FALSE, col.names = TRUE, fileEncoding = "UTF-8")})
  
  naes <- node_aes(
    shape = "box",
    fontname="Helvetica,Arial,sans-serif",
    penwidth = 0.75,
    style = "rounded") 
  
  naes2 <- node_aes(
    shape = "note",
    style = "filled",
    fillcolor="grey95")
  
  naes3 <- node_aes(
    shape = "box",
    fontname="Helvetica,Arial,sans-serif",
    penwidth = 0.75,
    style = "filled,rounded",
    fillcolor="YellowGreen")
  
  eaes1 <- edge_aes(
    color = "YellowGreen",
    style = "solid")
  
  eaes2 <- edge_aes(
    color = "gray",
    style = "dashed")
  
  graph <- reactive(
    create_graph(directed = TRUE, attr_theme = NULL) |>
      add_node(label = "Supplier", node_aes = naes3) |>
      add_node(label = "Rougher #1", node_aes = if(input$choose_rougher == "Rougher Turn #1") naes3 else naes) |>
      add_node(label = "Rougher #2", node_aes = if(input$choose_rougher == "Rougher Turn #2") naes3 else naes) |>
      add_node(label = "Rougher #3", node_aes = if(input$choose_rougher == "Rougher Turn #3") naes3 else naes) |>
      add_node(label = "Finisher", node_aes = naes3) |>
      add_node(label = round(process_data$supplier, 3), node_aes = naes2) |>
      add_node(label = round(process_data$rougher, 3), node_aes = naes2) |> 
      add_node(label = round(process_data$finisher, 3), node_aes = naes2) |> 
      
      add_edge(from = 1, to = 6, edge_aes = eaes1) |> 
      add_edge(from = 6, to = 2, edge_aes = if(input$choose_rougher == "Rougher Turn #1") eaes1 else eaes2) |> 
      add_edge(from = 6, to = 3, edge_aes = if(input$choose_rougher == "Rougher Turn #2") eaes1 else eaes2) |> 
      add_edge(from = 6, to = 4, edge_aes = if(input$choose_rougher == "Rougher Turn #3") eaes1 else eaes2) |> 
      add_edge(from = 2, to = 7, edge_aes = if(input$choose_rougher == "Rougher Turn #1") eaes1 else eaes2) |> 
      add_edge(from = 3, to = 7, edge_aes = if(input$choose_rougher == "Rougher Turn #2") eaes1 else eaes2) |> 
      add_edge(from = 4, to = 7, edge_aes = if(input$choose_rougher == "Rougher Turn #3") eaes1 else eaes2) |> 
      add_edge(from = 7, to = 5, edge_aes = eaes1) |> 
      add_edge(from = 5, to = 8, edge_aes = eaes1))
  
  output$diagram <- renderGrViz(
    grViz(generate_dot(graph())))}

shinyApp(ui = ui, server = server)
