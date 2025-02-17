args <- commandArgs(trailingOnly = TRUE)
tool_name <- args[1]

if (tool_name == "panelcn") {
  if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager", repos = "http://cran.r-project.org")
  }
  if (!requireNamespace("panelcn.mops", quietly = TRUE)) {
    BiocManager::install("panelcn.mops", ask = FALSE)
  } else {
    message("panelcn.mops has been installed.")
  }
} else if (tool_name == "cnvpanelizer") {
  if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager", repos = "http://cran.r-project.org")
  }
  if (!requireNamespace("CNVPanelizer", quietly = TRUE)) {
    BiocManager::install("CNVPanelizer", ask = FALSE)
  } else {
    message("CNVPanelizer has been installed.")
  }
} else if (tool_name == "decon") {
  required_packages <- c("R.utils", "optparse", "ExomeDepth")
  installed_packages <- rownames(installed.packages())
  
  for (pkg in required_packages) {
    if (!pkg %in% installed_packages) {
      install.packages(pkg, repos = "http://cran.r-project.org")
      message(pkg, " has been installed.")
    } else {
      message(pkg, " is already installed.")
    }
  }
} else {
  message("No environment setup required for tool: ", tool_name)
}
