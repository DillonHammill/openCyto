#' Hierarchical Gating Pipeline for flow cytometry data.
#' 
#' openCyto is a package designed to facilitate the automated gating methods in sequential way 
#' to mimic the manual gating strategy.
#'
#'
#' \tabular{ll}{
#' Package: \tab openCyto\cr
#' Type: \tab Package\cr
#' Version: \tab 1.2.8\cr
#' Date: \tab 2014-04-10\cr
#' License: \tab GPL (>= 2)\cr
#' LazyLoad: \tab yes\cr
#' }
#'
#' @author
#' Mike Jiang \email{wjiang2@@fhcrc.org},
#' John Ramey \email{jramey@@fhcrc.org},
#' Greg Finak \email{gfinak@@fhcrc.org}
#'
#' Maintainer: Mike Jiang \email{wjiang2@@fhcrc.org}
#' @name openCyto
#' @docType package
#' @title Hierarchical Gating Pipeline for flow cytometry data
#' @keywords package
#' @examples
#' \dontrun{gatingTemplate('test.csv')}
#' @seealso See \code{\link[openCyto]{gt_gating}}, 
#' \code{\link{gate_flowclust_1d}}, 
#' for an overview of gating functions.
NULL

#' a class storing the gating method and population information in a graphNEL object
#' 
#' Each cell population is stored in graph node and is connected with its parent population 
#' or its reference node for boolGate or refGate.
#' 
#' @rdname gatingTemplate-class 
#' @export 
#' @importClassesFrom graph graphNEL graphBase graph
#' @importClassesFrom Biobase AssayData
#' @name gatingTemplate-class
setClass("gatingTemplate", contains = "graphNEL", representation(name = "character"))

	
#' a virtual class that represents the gating result generated by flowClust gating function
#' 
#' Bascially it extends flowCore 'filter classes to have extra slot to store priors and posteriors
#' @name fcFilter-class
setClass("fcFilter", representation("VIRTUAL", priors = "list", posteriors = "list"))

#' a concrete class that reprents the polygonGate generated by flowClust
#' 
#' It stores priors and posteriors as well as the actual polygonGate.
#' @importClassesFrom flowCore polygonGate
#' @name fcPolygonGate-class
setClass("fcPolygonGate", contains = c("fcFilter", "polygonGate"))

#' a concrete class that reprents the ellipsoidGate generated by flowClust
#' 
#' It stores priors and posteriors as well as the actual ellipsoidGate.
#' @importClassesFrom flowCore ellipsoidGate
#' @name fcEllipsoidGate-class
setClass("fcEllipsoidGate", contains = c("fcFilter", "ellipsoidGate"))


#' a concrete class that reprents the rectangleGate generated by flowClust
#' 
#' It stores priors and posteriors as well as the actual rectangleGate.
#' @importClassesFrom flowCore rectangleGate
#' @name fcRectangleGate-class
setClass("fcRectangleGate", contains = c("fcFilter", "rectangleGate"))

#' constuctor for \code{fcRectangleGate}
#' 
#' @param x a \code{rectangleGate} object
#' @param priors a \code{list} storing priors
#' @param posts a \code{list} storing posteriors
fcRectangleGate <- function(x, priors, posts) {
  res <- as(x, "fcRectangleGate")
  res@priors <- priors
  res@posteriors <- posts
  res
}

#' constuctor for \code{fcPolygonGate}
#' @param x a \code{polygonGate} object
#' @inheritParams fcRectangleGate
fcPolygonGate <- function(x, priors, posts) {
  res <- as(x, "fcPolygonGate")
  res@priors <- priors
  res@posteriors <- posts
  res
}

#' constuctor for \code{fcEllipsoidGate}
#' @param x a \code{ellipsoidGate} object
#' @inheritParams fcRectangleGate
fcEllipsoidGate <- function(x, priors, posts) {
  res <- as(x, "fcEllipsoidGate")
  res@priors <- priors
  res@posteriors <- posts
  res
}


#' a class that extends \code{filterList} class.
#' 
#' Each filter in the filterList must extends the \code{fcFilter} class
#' @importClassesFrom flowCore filterList
#' @name fcFilterList-class
setClass("fcFilterList", contains = "filterList")

#' constuctor for \code{fcFilterList}
#' 
#' @param x \code{list} of \code{fcFilter} (i.e. \code{fcPolygonGate} or \code{fcRectangleGate})
#' 
fcFilterList <- function(x) {
  
  if (!all(unlist(lapply(x, function(i) extends(class(i), "fcFilter"))))) {
    stop("not all filters are fcFilter!")
  }
  if (class(x) == "list") {
    x <- filterList(x)
  }
  
  sname <- names(x)
  x <- as(x, "fcFilterList")
  
  attr(x, "names") <- sname
  x
}

 
#' A class to represent a flowClust tree.
#' 
#' It is a graphNEL used as a container to store priors and posteriors for each flowClust gate that can be
#' visualized for the purpose of fine-tunning parameters for flowClust algorithm
#' 
#' @name fcTree-class
setClass("fcTree", contains = "gatingTemplate")

#' constructor of \code{fcTree}
#' 
#' It adds an extra node data slot "fList"(which is a \code{filterList} object) to the \code{gatingTemplate}
#'  
#' @param gt a \code{gatingTemplate} object
fcTree <- function(gt) {
  res <- as(gt, "fcTree")
  nodeDataDefaults(res, "fList") <- new("filterList")
  res
}

#' A class to represent a gating method.
#' 
#' A gating method object contains the specifics for generating the gates.
#' 
#' @section Slots:
#'  \describe{
#' 
#'      \item{name}{ a \code{character} specifying the name of the gating method}
#
#'      \item{dims}{ a \code{character} vector specifying the dimensions (channels or markers) of the gate}
#' 
#'      \item{args}{ a \code{list} specifying the arguments passed to gating function}
#' 
#'      \item{groupBy}{ a \code{character} or \code{integer} specifying how to group the data.
#'                   If \code{character}, group the data by the study variables (columns in \code{pData}).
#'                    If \code{integer},  group the data by every \code{N} samples.
#'                   }
#' 
#'      \item{collapse}{ a \code{logical} specifying wether to collapse the data within group before gating.
#'                  it is only valid when \code{groupBy} is specified}
#'  }
#' 
#' 
#' 
#' @rdname gtMethod-class 
#' @name gtMethod-class
#' @aliases gtMethod
#' @examples 
#'  \dontrun{
#'      gt <- gatingTemplate(system.file("extdata/gating_template/tcell.csv",package = "openCyto"))
#'      gh_pop_get_gate(gt, '2', '3')
#' }
setClass("gtMethod", representation(name = "character"
                                    , dims = "character"
                                    , args = "list"
                                    , groupBy = "ANY"
                                    , collapse = "logical"
                                    )
          )

          
#' A class to represent a preprocessing method.
#' 
#' It extends \code{gtMethod} class.
#' 
#' @name ppMethod-class
#' @aliases ppMethod
#' @examples 
#'  \dontrun{
#'      gt <- gatingTemplate(system.file("extdata/gating_template/tcell.csv",package = "openCyto"))
#'      ppMethod(gt, '3', '4')
#' }     
setClass("ppMethod", contains = "gtMethod")


#' A class to represent a reference gating method.
#' 
#' It extends \code{gtMethod} class.
#' 
#' @section Slots:
#' \describe{ 
#'  \item{refNodes}{ \code{character} specifying the reference nodes}
#' }
#' @name refGate-class      
setClass("refGate", contains = "gtMethod", representation(refNodes = "character"))

#' A class to represent a dummy gating method that does nothing but serves as reference to be refered by other population
#' 
#' It is generated automatically by the csv template preprocessing to handle the gating function that returns multiple gates. 
setClass("dummyMethod", contains = "refGate")


#' A class to represent a boolean gating method.
#' 
#' It extends \code{refGate} class.
#' @name boolMethod-class
setClass("boolMethod", contains = "refGate")

#' A class to represent a polyFunctions gating method.
#' 
#' It extends \code{boolMethod} class and will be expanded to multiple \code{boolMethod} object.
#' 
#' @name polyFunctions-class
setClass("polyFunctions", contains = "boolMethod")

#' A class to represent a cell population that will be generated by a gating method.
#' 
#' @section Slots: 
#' \describe{
#' 
#'  \item{id}{ \code{numeric} unique ID that is consistent with node label of graphNEL in gating template} 
#'  \item{name}{ \code{character} the name of population}
#'  \item{alias}{ \code{character} the more user friendly name of population}
#' }
#' @name gtPopulation-class
#' @examples 
#'  \dontrun{
#'      gt <- gatingTemplate(system.file("extdata/gating_template/tcell.csv",package = "openCyto"))
#'       
#'      gt_get_nodes(gt, '2')
#' }
setClass("gtPopulation", representation(id = "character", name = "character",
                                        alias = "character"
                                  )
                              )
                              
                              
#' A class representing a group of cell populations.
#' 
#' It extends \code{gtPopulation} class.
#' @name gtSubsets-class
setClass("gtSubsets", contains = "gtPopulation")

#' A function to tell wether a gating method is \code{polyFunctions}
#' 
#' @rdname isPolyfunctional
#' @param gm an object that extends \code{gtMethod}  
#' @noRd 
.isPolyfunctional <- function(gm) {
  # grepl('^\\[\\:.+\\:\\]$',x)
  class(gm) == "polyFunctions"
}

#' gating arguments parser
#' 
#' parsing the arguments read from `args` columns of csv template into 
#' list of paired arguments
#' @noRd 
.argParser <- function(txt, split = TRUE) {
  # trim whitespaces at beginning and the end of string
  txt <- gsub("^\\s*|\\s*$", "", txt)

  if (split) {
    paired_args <- paste("c(", txt, ")")
    paired_args <- try(parse(text = paired_args), silent = TRUE)
    if (class(paired_args) == "try-error") {
      errmsg <- attr(paired_args, "condition")
      msg <- conditionMessage(errmsg)
      stop("invalid gating argument:\n", msg)
    }
    
    paired_args <- as.list(as.list(paired_args)[[1]])[-1]
    names(paired_args) <- names(paired_args)
  } else {
    if(nchar(txt) >0){
      paired_args <- as.symbol(txt)
      paired_args <- list(paired_args)  
    }else
      stop("argument is empty!")
    
  }
  
  paired_args
}


 

#' @title
#' gatingTemplate constructor 
#' 
#' @description 
#' It parses the csv file that specifies the gating scheme for a particular staining pannel. 
#' 
#' @details 
#' This csv must have the following columns:
#' 
#' 'alias': a name used label the cell population, the path composed by the alias and its precedent nodes (e.g. /root/A/B/alias) has to be uniquely identifiable.
#'          So alias can not contain '/' character, which is reserved as path delimiter.
#'  
#' 'pop': population patterns of '+/-` or '+/-+/-', which tells the algorithm which side (postive or negative) of 1d gate or which quadrant of 2d gate to be kept.
#'                         
#' 'parent': the parent population alias, its path has to be uniquely identifiable.
#'  
#' 'dims': characters seperated by comma specifying the dimensions(1d or 2d) used for gating. 
#' It can be either channel name or stained marker name (or the substrings of channel/marker names as long as they are uniquely identifiable.).
#'  
#' 'gating_method': the name of the gating function (e.g. 'flowClust'). It is invoked by a wrapper function that has the identical function name prefixed with a dot.(e.g. '.flowClust')
#'     
#' 'gating_args': the named arguments passed to gating function (Note that double quotes are often used as text delimiter by some csv editors. So try to use single quote instead if needed.)
#'  
#' 'collapseDataForGating': When TRUE, data is collapsed (within groups if 'groupBy' specified) before gating and the gate is replicated across collapsed samples.
#'  When set FALSE (or blank),then 'groupBy' argument is only used by 'preprocessing' and ignored by gating.
#'    
#' 'groupBy': If given, samples are split into groups by the unique combinations of study variable (i.e. column names of pData,e.g."PTID:VISITNO").
#'  when split is numeric, then samples are grouped by every N samples 
#' 
#' 'preprocessing_method': the name of the preprocessing function(e.g. 'prior_flowclust'). It is invoked by a wrapper function that has the identical function name prefixed with a dot.(e.g. '.prior_flowclust')
#'  the preprocessing results are then passed to gating wrapper function through 'pps_res' argument.
#'       
#' 'preprocessing_args': the named arguments passed to preprocessing function.
#' 
#'     
#' @rdname gatingTemplate-class 
#' @examples
#' \dontrun{ 
#'   gt <- gatingTemplate(system.file("extdata/gating_template/tcell.csv",package = "openCyto"))
#'   plot(gt)
#' }
#' 
#' @export
setGeneric("gatingTemplate", function(x, ...) standardGeneric("gatingTemplate"))

#' @aliases gatingTemplate,character-method
#' @param x \code{character} csv file name or a \code{data.table}
#' @param name \code{character} the label of the gating template
#' @param strict \code{logical} whether to perform validity check(special characters) on the alias column. By default it is(and should be) turned on for the regular template parsing. 
#'                              But sometime it is useful to turned it off to bypass the check for the dummy nodes(e.g. the csv template generated by 'gh_generate_template'  with some existing boolean gates that has '!' or ':' symbol).
#' @param strip_extra_quotes \code{logical} Extra quotes are added to strings by fread. This causes problems with parsing R strings to expressions in some cases. Default FALSE for usual behaviour. TRUE should be passed if parsing gating_args fails.
#' @param ... other arguments passed to \code{data.table::fread}
#' @importFrom graph graphNEL addEdge nodes edges nodeDataDefaults nodeData edgeDataDefaults addEdge edgeData subGraph
#' @rdname gatingTemplate-class
setMethod("gatingTemplate", signature(x = "character"), function(x, name = "default", strict = TRUE, strip_extra_quotes=FALSE,...) {
      dt <- fread(x, ...)
      # empty gatingTemplate error
      if(nrow(dt) == 0) {
        stop(
          paste0(
            "Cannot create gatingTemplate from ",
            x, 
            " as it contains no gating entries."
          )
        )
      }
      dt <- .preprocess_csv(dt, strict = strict)
      #append the isMultiPops column based on pop name
      dt[, isMultiPops := FALSE]
      dt[pop == "*", isMultiPops := TRUE]
	if(strip_extra_quotes)
      		{
			dt[,gating_args:=gsub("\"\"","\"",gating_args)]
		}
      .gatingTemplate(dt, name = name)
    })

#' @aliases gatingTemplate,data.table-method
#' @rdname gatingTemplate-class
setMethod(
  "gatingTemplate", 
  signature(x = "data.table"), 
  function(x, 
           name = "default", 
           strict = TRUE, 
           strip_extra_quotes = FALSE,
           ...) {
    # empty gatingTemplate error
    if(nrow(x) == 0) {
      stop(
        paste0(
          "Cannot create gatingTemplate from this data.table as it ",
          "contains no gating entries."
        )
      )
    }
    dt <- .preprocess_csv(x, strict = strict)
    #append the isMultiPops column based on pop name
    dt[, isMultiPops := FALSE]
    dt[pop == "*", isMultiPops := TRUE]
    if(strip_extra_quotes)
    {
      dt[,gating_args:=gsub("\"\"","\"",gating_args)]
    }
    .gatingTemplate(dt, name = name)
  }
)

#' @importFrom graph nodeDataDefaults<- edgeDataDefaults<- nodeData<- edgeData<-
#' @noRd 
.gatingTemplate <- function(dt, name = "default"){  
#  browser()
  # create graph with root node
#  browser()
  g <- graphNEL(nodes = "root", edgemode = "directed")
  g <- as(g, "gatingTemplate")
  nodeDataDefaults(g, "pop") <- ""
  edgeDataDefaults(g, "gtMethod") <- ""
  edgeDataDefaults(g, "ppMethod") <- ""
  edgeDataDefaults(g, "isReference") <- FALSE
  
  # add default root
  nodeData(g, "root", "pop") <- new("gtPopulation", id = "root", name = "root", alias = "root")

  # parse each row
  nEdges <- nrow(dt)
  edgs <- vector("list", nEdges)
  for (i in 1:nEdges) {
    
    thisRow <- dt[i,]
    # extract info from dataframe
    parent <- thisRow[,parent][[1]]
    
    # get parent ID
    
    curPop <- thisRow[,alias][[1]]
    
    if(grepl("/", curPop))
      stop("Population name(or alias) '", curPop , "' contains '/', which is reserved as gating path delimiter!")
    
    curNodePath <- paste(parent, curPop, sep = "/")
    curNodePath <- sub("root", "", curNodePath)
    curPopName <- thisRow[, pop][[1]]
    isMultiPops <- thisRow[, isMultiPops]
    #try to split alias for the gating function that returns multi-pops
    if(isMultiPops)
        curPop <- trimws(unlist(strsplit(split = ",", curPop)))
    # create pop object
    curNode <- new("gtPopulation", id = curNodePath, name = curPopName, 
                        alias = curPop
                )
                      
    # create gating method object
    cur_method <- thisRow[, gating_method][[1]]
    cur_args <- thisRow[, gating_args][[1]]
    cur_dims <- thisRow[, dims][[1]]
    
    cur_collapse <- thisRow[, collapseDataForGating][[1]]
    if(cur_collapse == "")
      cur_collapse <- FALSE
    cur_collapse <- as.logical(cur_collapse)
    
    if(is.na(cur_collapse))
      stop("Invalid `collapseDataForGating` flag!")
    
    cur_groupBy <- thisRow[, groupBy][[1]]
    cur_method_name_pattern <- paste0("^", cur_method , "$")
    # do not parse args for refGate-like gate since they might break the current
    # parse due to the +/- | &,! symbols
    if (any(grepl(cur_method_name_pattern,  c("boolGate", "polyfunctions", "refGate", "dummy_gate"), ignore.case = TRUE))) {
      split_args <- FALSE
    } else {
      split_args <- TRUE
    }
    
    cur_args <- .argParser(cur_args, split_args)
    
    gm <- new("gtMethod"
                , name = cur_method
                , dims = cur_dims
                , args = cur_args
                , collapse = cur_collapse
                , groupBy = cur_groupBy
              )
    # specialize gtMethod as needed
    if (grepl(cur_method_name_pattern , "boolGate", ignore.case = TRUE)) {
      gm <- as(gm, "boolMethod")
    } else if (grepl(cur_method_name_pattern , "polyFunctions", ignore.case = TRUE)) {
      gm <- as(gm, "polyFunctions")
    } else if (grepl(cur_method_name_pattern , "refGate", ignore.case = TRUE)) {
      gm <- as(gm, "refGate")
      if(nchar(cur_dims) == 0){
        stop("No dimensions defined for refGate!")
      }
    }
    if (grepl(cur_method_name_pattern , "dummy_gate", ignore.case = TRUE)) 
      gm <- as(gm, "dummyMethod")
    
    #preprocessing object
    cur_pp_Method <- thisRow[, preprocessing_method][[1]]
    cur_pp_args <- thisRow[, preprocessing_args][[1]]
    cur_pp_args <- .argParser(cur_pp_args, TRUE)
    
    if(nchar(cur_pp_Method) > 0)
      ppm <- new("ppMethod"
                  , name = cur_pp_Method
                  , dims = cur_dims
                  , args = cur_pp_args
                  , collapse = cur_collapse
                  , groupBy = cur_groupBy
                )
    
    message("Adding population:", basename(curNodePath))
#    browser()
    # add current node to graph
    g_updated <- graph::addNode(curNodePath, g)
    
#    if (!extends(class(gm), "refGate")) {
      # add edge from parent
    g_updated <- addEdge(parent, curNodePath, g_updated)
    
    #add preprcessing method to the edge
    if(nchar(cur_pp_Method) > 0)
      edgeData(g_updated, parent, curNodePath, "ppMethod") <- ppm
    
    ##########################################
    # refGate-like methods need extra parsing
    ##########################################
    if (extends(class(gm), "refGate")) {
      
      # get argument
      args <- gm@args[[1]]
      args <- deparse(args)
      
      # parsing reference nodes
      if (class(gm) == "boolMethod") {
        # strip ! symbols
        args <- gsub("!", "", args)
        # split by logical operator when regular boolean gates
        refNodes <- strsplit(args, "&|\\|")[[1]]
      } else {
        # split by colon for refGate or polyfunctional boolean gates
        refNodes <- strsplit(args, "\\:")[[1]]
      }
      
      # update refNodes slot of gm object
      gm@refNodes <- refNodes
      
      # specialize the node type for polyfunctions
      if (class(gm) == "polyFunctions") {
#        browser()
        curNode <- as(curNode, "gtSubsets")
      }
      
      # add edges from reference nodes (only used for tsort)
      for (ref_node in refNodes) {
        
        # add the edge from it
        g_updated <- addEdge(.getFullPath(ref_node, dt), curNodePath, g_updated)

        # flag the edge 
        edgeData(g_updated, .getFullPath(ref_node, dt), curNodePath, "isReference") <- TRUE
      }
    }
    
    # attach the gm object to the parent edge
    edgeData(g_updated, parent, curNodePath, "gtMethod") <- gm
    # flag the edge 
    edgeData(g_updated, parent, curNodePath, "isReference") <- FALSE
    # add the current population object to the current node
    nodeData(g_updated, curNodePath, "pop") <- curNode
    # update graph
    g <- g_updated
  }
  
  g@name <- name
  g
}
 
