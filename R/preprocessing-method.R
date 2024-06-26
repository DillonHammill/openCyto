setGeneric("preprocessing", function(x, y, ...) standardGeneric("preprocessing"))

#' apply a \link[openCyto:ppMethod-class]{ppMethod} to the \code{GatingSet}
#' 
#' @param x \code{ppMethod}
#' @param y \code{GatingSet} or \code{GatingSetList}
#' @param ... other arguments
#' 
#' @inheritParams .preprocessing
#' 
#' @aliases preprocessing,ppMethod,GatingSet-method
setMethod("preprocessing", signature = c("ppMethod", "GatingSet"),
    definition = function(x, y, ...) {
      .preprocessing(x,y,...)
    })
setMethod("preprocessing", signature = c("ppMethod", "GatingSetList"),
    definition = function(x, y, ...) {
      .preprocessing(x,y,...)
    })

update_list <- function (x, val) 
{
  if (is.null(x)) 
    x <- list()
  modifyList(x, val)
}
#' internal function (preprocessing)
#' 
#' @importFrom flowWorkspace sampleNames
#' @inheritParams .gating_gtMethod
#' @param gm: \code{gtMethod} object
#' @noRd 
.preprocessing <- function(x, y, gtPop, parent, gm
                            , mc.cores = 1, parallel_type = c("none", "multicore", "cluster"), cl = NULL
                            , ...) {
  requireNamespace("parallel")
  
  args <- parameters(x)
  # overwrite the golbal args with the local one
  args <- update_list(args,list(...))
  parallel_type <- match.arg(parallel_type)
  
  ppm <- paste0(".", names(x))
  if(!.isRegistered(ppm)){
    stop(sprintf("Can't gate using unregistered method %s",ppm))
  }
  groupBy <- groupBy(x)
  isCollapse <- isCollapse(x)
  dims <- dims(x)
  is_1d_gate <- any(is.na(dims))
  
  popAlias <- alias(gtPop)
  popName <- names(gtPop)
  popId <- gtPop@id
  
  gs_nodes <- basename(gs_pop_get_children(y[[1]], parent))
  if (length(gs_nodes) == 0 || !popAlias %in% gs_nodes) {
    message("Preprocessing for '", popAlias, "'")
    
    parent_data <- gs_pop_get_data(y, parent)
    channels <- sapply(dims, function(channel)as.character(getChannelMarker(parent_data[[1, use.exprs = FALSE]], channel)$name))
    
    # when groupBy is set distribute the subset for each group to preprocessing function
    # otherwise, the entire data set is passed (which is different from the way we handle gating function)
    if (nchar(groupBy) > 0) {
      
      split_by <- as.character(groupBy)
      suppressWarnings(split_by_num <- as.numeric(groupBy))
      #split by every N samples
      if(!is.na(split_by_num)){
        nSamples <- length(parent_data)
        if(nSamples==1){
          split_by <- 1
        }else{
          split_by <-  rep(1:nSamples, each = split_by_num, length.out= nSamples)  
        }
        
      }else{
        
        #split by study variables
        pd <- pData(parent_data)
        split_by <- strsplit(split_by, ":")[[1]]
        split_by <- apply(pd[, split_by, drop = FALSE], 1, function(i)paste(i, collapse = ":"))
        split_by <- as.character(split_by)
      }
      fslist <- split(parent_data, split_by)
    }else {
      # all samples same group named "all" - matches .gating_gtMethod()
      if(isCollapse) {
        fslist <- list("all" = parent_data) 
      } else {
        fslist <- split(parent_data, sampleNames(parent_data))
      }
    } 
    
    # construct method call
    thisCall <- substitute(f1())
    thisCall[["X"]] <- quote(fslist)  #set data
    thisCall[["FUN"]] <- as.symbol(ppm)  #set gating method
    thisCall[["channel"]] <- channels 
    thisCall[["gs"]] <- y
    thisCall[["gm"]] <- gm
    thisCall[["groupBy"]] <- groupBy
    thisCall[["isCollapse"]] <- isCollapse
    
    #we don't want to deal with subSampling in preprocessing
    #since it will increase the IO overhead in order to determine 
    #total number of events
    if(!(all(is.na(args)))){
      for (arg in names(args)) {
        thisCall[[arg]] <- args[[arg]]
      } 
    }
    
    if (parallel_type == "multicore") {
      message("Running in parallel mode with ", mc.cores, " cores.")
      thisCall[[1]] <- quote(mclapply)
      thisCall[["mc.cores"]] <- mc.cores
    }else if(parallel_type == "cluster"){
      if(is.null(cl))
        stop("cluster object 'cl' is empty!")
      thisCall[[1]] <- quote(parSapply)
      thisCall[["cl"]] <- cl
      thisCall[["SIMPLIFY"]] <- TRUE
    }else {
      thisCall[[1]] <- quote(lapply)  #select loop mode
      
    }
    
    res <- eval(thisCall)
    
    # when isCollapse == FALSE, the gating is done at each individual FCS sample
    # Thus we want to unlist the pps_res to FCS file level
    if(!isCollapse)
      res <- unlist2(res, recursive = FALSE)
      
    

  } else {
    message("Skip preprocessing! Population '", paste(popAlias, collapse = ","), "' already exists.")
    res <- NULL
  }
  
  
  
  res
  
}
# copied from AnnotationDbi that does not mangle the name
unlist2 <- function (x, recursive = TRUE, use.names = TRUE, what.names = "inherited") 
{
  ans <- unlist(x, recursive, FALSE)
  if (!use.names) 
    return(ans)
  if (!is.character(what.names) || length(what.names) != 1) 
    stop("'what.names' must be a single string")
  what.names <- match.arg(what.names, c("inherited", "full"))
  names(ans) <- unlist(make.name.tree(x, recursive, what.names), 
      recursive, FALSE)
  ans
}
# copied from AnnotationDbi that does not mangle the name
make.name.tree <- function (x, recursive, what.names) 
{
  if (!is.character(what.names) || length(what.names) != 1) 
    stop("'what.names' must be a single string")
  what.names <- match.arg(what.names, c("inherited", "full"))
  .make.name.tree.rec <- function(x, parent_name, depth) {
    if (length(x) == 0) 
      return(character(0))
    x_names <- names(x)
    if (is.null(x_names)) 
      x_names <- rep.int(parent_name, length(x))
    else if (what.names == "full") 
      x_names <- paste0(parent_name, x_names)
    else x_names[x_names == ""] <- parent_name
    if (!is.list(x) || (!recursive && depth >= 1L)) 
      return(x_names)
    if (what.names == "full") 
      x_names <- paste0(x_names, ".")
    lapply(seq_len(length(x)), function(i) .make.name.tree.rec(x[[i]], 
              x_names[i], depth + 1L))
  }
  .make.name.tree.rec(x, "", 0L)
}
