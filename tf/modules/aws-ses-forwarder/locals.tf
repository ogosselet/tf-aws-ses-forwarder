# Very simple tagging "startegy" - feel free to update to meet your requirements 
locals {
  tags = merge(
    var.common_tags,
    {
      CreationDate = timestamp()
    }
  )
}

 