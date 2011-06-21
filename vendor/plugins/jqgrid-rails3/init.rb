require '2dc_jqgrid'

Array.send :include, JqgridJson
ActionView::Base.send :include, Jqgrid
ActionController::Base.send :include,JqgridFilter