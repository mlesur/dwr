
#' Front-end du module pour afficher un graphique dans un panel
#'
#' @param id shiny id
#' @param title Titre du panel
#' @param description Description du graphique
#' @param i18n Objet pour traduire

graphique_ui <- function(id, title, header, note, collapsed, i18n) {
  
  ns <- NS(id)
  
  column(
    width = 6,
    collapseUI(
      id = ns("collapse"),
      title = h4(i18n$t(title)),
      collapsed = collapsed,
      class = "graphique",
      content = tagList(
        p(i18n$t(header)),
        plotOutput(
          outputId = ns("plot"),
          hover = hoverOpts(
            id = ns("hover"),
            delay = 100,
            delayType = "debounce",
            nullOutside = TRUE
          )
        ),
        tags$small(i18n$t(note)),
        uiOutput(ns("hover"), class = "graphique-tooltip"),
        fluidRow(
          shinyWidgets::downloadBttn(
            ns("dwn_svg"),
            label = "svg", style = "minimal", size = "xs", color = "succes"
          ) |>
            shinyjs::hidden(),
          shinyWidgets::downloadBttn(
            ns("dwn_png"),
            label = "png", style = "minimal", size = "xs", color = "succes"
          ) |>
            shinyjs::hidden(),
          shinyWidgets::downloadBttn(
            ns("dwn_csv"),
            label = "csv", style = "minimal", size = "xs", color = "succes"
          ) |>
            shinyjs::hidden(),
          actionLink(
            class = "copy-btn",
            inputId = ns("copy"),
            label = NULL,
            icon = icon_colored("copy", "#1DA1F2", size="xs")
          ),
          span(id = ns("copy-success"), class = "copy-success")
        )
      )
    )
  )
}

# serveur ----------------
graphique_server <- function(id, pre_plot, vvars, sim, gl, i18n) {
  moduleServer(id, function(input, output, session) {
    
    output$plot <- renderPlot({
      post_plot_sim(
        pre_plot(),
        vvars
      )
    })
    outputOptions(output, "plot", suspendWhenHidden = FALSE)
    ## hover -------
    output$hover <- renderUI(
      hover_on_plot(
        pre_plot(),
        vvars,
        input$hover
      )
    )
    ## dwn svg ---------
    output$dwn_svg <- downloadHandler(
      filename = function() {
        uuids <- pre_plot()$data_alt |>
          distinct(uuid) |>
          pull(uuid)
        return(dwr_file_name(ext="svg", id, sim()$country, uuids))
      },
      content = function(file) {
        ggplot2::ggsave(
          filename = file,
          plot = {
            uuids <- pre_plot()$data_alt |> 
              distinct(uuid) |> 
              pull(uuid)
            if(length(uuids)>1)
              uuids <- str_c(uuids, collapse = "-")
            plot <- post_plot_sim(
              pre_plot(),
              vvars,
              title = gl$panels$names[[id]],
              pays = gl$cty2code[[sim()$country]],
              uuid = uuids
            )+theme(text = element_text("roboto"))
          }
          ,
          width = 11.2, height = 5, units = "in", bg = "white"
        )
      }
    )
    ## dnw png -------------------------
    output$dwn_png <- downloadHandler(
      filename = function() {
        uuids <- pre_plot()$data_alt |>
          distinct(uuid) |>
          pull(uuid)
        return(dwr_file_name(ext="png", id, sim()$country, uuids))
      },
      content = function(file) {
        ggplot2::ggsave(
          filename = file,
          plot = {
            uuids <- pre_plot()$data_alt |> 
              distinct(uuid) |> 
              pull(uuid)
            if(length(uuids)>1)
              uuids <- str_c(uuids, collapse = "-")
            post_plot_sim(
              pre_plot(),
              vvars,
              title = gl$panels$names[[id]],
              pays = gl$cty2code[[sim()$country]],
              uuid = uuids
            )+theme(text = element_text("roboto"))
          },
          width = 11, height = 8, units = "in", bg="white", dpi = 72
        )
      }
    )
    ## dnw csv
    output$dwn_csv <- downloadHandler(
      filename = function() {
        uuids <- pre_plot()$data_alt |>
          distinct(uuid) |>
          pull(uuid)
        return(dwr_file_name(ext="csv", id, sim()$country, uuids))
      },
      content = function(file) {
        data <- pre_plot()$data_alt |>
          dplyr::filter(variable %in% vvars) |>
          dplyr::arrange(uuid, variable, year) |>
          dplyr::select(uuid, variable, year,  q0.5, q0.025, q0.975) |> 
          dplyr::mutate(label = map_chr(variable,~i18n$t(gl$vars$label[[.x]])))
        readr::write_csv(data, file = file)
      }
    )
    
    ## show btn ------------------------
    observe({
      if (is.null(sim())||sim()$uuid == "")
        return(NULL)
      shinyjs::show(id = "dwn_svg_bttn")
      shinyjs::show(id = "dwn_png_bttn")
      shinyjs::show(id = "dwn_csv_bttn")
    })
    
  }) # moduleserver
} # graphique_server function

dwr_file_name <- function(ext = "svg", ...) {
  str_c(str_c(purrr::flatten(list(...)), collapse="_"), ".", ext)  |> tolower()
}
