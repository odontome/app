module Jqgrid

  def jqgrid_stylesheets(theme="default")
      stylesheet_link_tag "jqgrid/themes/#{theme}/jquery-ui-1.8.custom.css", 
        'jqgrid/ui.jqgrid.css', 
        :cache => "jqgrid-#{theme}-css"
    end

    def jqgrid_javascripts
      locale = I18n.locale rescue :en
      javascript_include_tag "jqgrid/i18n/grid.locale-#{locale}.js",
        'jqgrid/jquery.jqGrid.min.js',
        # Don't know if we need it, if smth not working, just uncomment it
        #'jqgrid/grid.tbltogrid',
        'jqgrid/jquery.contextmenu.r2.packed.js',
        'jqgrid/jquery.cookie.js',
        :cache => 'jqgrid-js'
    end

    def jqgrid(title, id, action, columns = [], options = {})
      
      # Default options
      options = 
        { 
          :rows_per_page       => '10',
          :sort_column         => '',
          :sort_order          => '',
          :height              => '240',
          :gridview            => 'false',
          # If specified will create a handler using the specified
          # string as the name of the error handler function. Default
          # error handling code will be created for this function.
          :error_handler       => 'null',  
          # The other option is to pass in the name of a custom error handler
          # created external to this plugin, to use this do not specify an
          # :error_handler option and specify the name of the custom error 
          # handler using this option.
          :custom_error_handler=> 'null',
          :inline_edit_handler => 'null',         
          :add                 => 'false',
          :delete              => 'false',
          :search              => 'true',
          :edit                => 'false',          
          :view                => 'false',          
          :inline_edit         => 'false',
          :autowidth           => 'false',
          :rownumbers          => 'false',
          :viewrecords         => 'true',
          :rowlist             => '[10,25,50,100]',
          :pagerpos            => 'center',
          :hiddengrid          => 'false',
          :hidegrid            => 'false',
          :shrinkToFit         => 'true',
          :form_width          => 300,
          :loadui              => 'enable',
          :context_menu        => {:menu_bindings => nil, :menu_id => nil},
          # Recreate the edit/add dialogs by default do not cache
          :recreateForm        => 'true'
        }.merge(options)
      
      # Stringify options values
      options.inject({}) do |options, (key, value)|
        options[key] = (key != :subgrid && key != :context_menu) ? value.to_s : value
        options
      end
      
      edit_button = (options[:edit].to_s == 'true' && options[:inline_edit].to_s == 'false').to_s
      
      # Setup error handler if required
      error_handler_code = ''
      error_handler_name = 'null'
      if options[:error_handler] == 'null' && options[:custom_error_handler] == 'null'
        # If no error handlers return true
        options[:error_handler_return_value] = 'true;'
      else
        if options[:error_handler] == "null"
          # Setup custom handler
          error_handler_name = options[:custom_error_handler]
          options[:error_handler_return_value] = options[:custom_error_handler]
        else
          # Construct default error handler code
          error_handler_name = options[:error_handler]    
          options[:error_handler_return_value] = options[:error_handler]
          error_handler_code = %Q/function #{options[:error_handler]}(r, data, action) {
            var resText=JSON.parse(r.responseText);
            if (resText[0]==true) {
              $('#flash_alert').html("<span class='ui-icon ui-icon-info' style='float:left; margin-right:.3em;'><\/span>"+resText[1]);
              $('#flash_alert').slideDown();
              window.setTimeout(function() {
                $('#flash_alert').slideUp();
                }, 3000);
                return [resText[0]]
              }else{
                return [resText[0],resText[1]]
              }
          }/
        end        
      end
      
      # Generate columns data
      col_names, col_model = gen_columns(columns)

      # Enable filtering (by default)
      search = ""
      filter_toolbar = ""
      if options[:search] == 'true'
        search = %Q/.navButtonAdd("##{id}_pager",{caption:"",title:$.jgrid.nav.searchtitle, buttonicon :'ui-icon-search', onClickButton:function(){ mygrid[0].toggleToolbar() } })/
        filter_toolbar = "mygrid.filterToolbar();"
        filter_toolbar << "mygrid[0].toggleToolbar()"
      end
     
      # Enable sortableRows
      sortableRows=""
      
      
      # Enable multi-selection (checkboxes)
      multiselect = "multiselect: false,"
      multiselect_handlers = ''
      cookie_array = ''
      if options[:multi_selection]
        multiselect = "multiselect: true,"
        multihandler = %Q/
          jQuery("##{id}_select_button").click(function() { 
            var s; s = jQuery("##{id}").getGridParam('selarrrow'); 
            #{options[:selection_handler]}(s); 
            return false;
          });/
        # Create object to manage cookie array used to store our selections
        cookie_array = %Q~
          var cookieArray = function(cookieName) {
            // When the cookie is saved the items will be a comma separated string
            // so we will split the cookie by comma to get the original array
            // Get the cookie if it exists
            var cookie = $.cookie(cookieName);
            // Load the items or a new array if null.
            var items = cookie ? cookie.split(/,/) : new Array();

            // Return a object that we can use to access the array.
            return {
              "add": function(val) {
                // Add value to the items.
                items.push(val);
              },
              "delete": function(val) {
                // Remove value from the items.
                if($.inArray(val, items) > -1) items.splice($.inArray(val, items), 1);
              },
              "clear": function() {
                //clear the cookie.
                $.cookie(cookieName, null);
              },
              "save": function() {
                // Save the items to a cookie.
                $.cookie(cookieName, items.join(','));
              },
              "exists": function(val) {
                // Check if value exists in array
                return ($.inArray(val, items) > -1);
              },
              "items": function() {
                // Get all the items.
                return items;
              }
            }
          }
          // Clear cookie if it exists
          var selected_records = new cookieArray("#{id}_selected_records");
          selected_records.clear();
        ~
        # Create handlers to handle selection
        multiselect_handlers = %Q~
          // Handles single record selection
          onSelectRow: function(id, selected){
            var selected_records = new cookieArray("#{id}_selected_records");
            if (selected) {
              selected_records.add(id);
            } else {
              selected_records.delete(id);
            }
            // Save the cookie
            selected_records.save();
          },
          // Handle select all
          onSelectAll: function(ids, selected){
            var selected_records = new cookieArray("#{id}_selected_records");
            // Process the ids
            alert(selected_records.items());
            $.each(ids, function (i, id) {
              if (selected) {
                selected_records.add(id);
              } else {
                selected_records.clear();
              }
            });
            // Save the cookie
            selected_records.save();
            alert(selected_records.items());
          },
          gridComplete: function(){
            // Hide the select all checkbox if required
            #{options[:hide_select_all] ? "jQuery('#cb_#{id}').hide();" : ''}
            // Get cookie
            var selected_records = new cookieArray("#{id}_selected_records");
            // Check if we have selections
            if (selected_records.items().length > 0) {
              var grid = jQuery("##{id}");
              // Process and apply selections
              grid_ids = grid.getDataIDs();
              $.each(grid.getDataIDs(), function (i, id) {
                if (selected_records.exists(id)) {
                  grid.setSelection(id, false);
                }
              });
            }
          },
        ~
      end

      # Enable master-details
      masterdetails = ""
      if options[:master_details]
        masterdetails = %Q/
          onSelectRow: function(ids) { 
            if(ids == null) { 
              ids=0; 
              if(jQuery("##{id}_details").getGridParam('records') >0 ) 
              { 
                jQuery("##{id}_details").setGridParam({url:"#{options[:details_url]}?q=1&id="+ids,page:1})
                .setCaption("#{options[:details_caption]}: "+ids)
                .trigger('reloadGrid'); 
              } 
            } 
            else 
            { 
              jQuery("##{id}_details").setGridParam({url:"#{options[:details_url]}?q=1&id="+ids,page:1})
              .setCaption("#{options[:details_caption]} : "+ids)
              .trigger('reloadGrid'); 
            } 
          },/
      end

      # Enable selection link, button
      # The javascript function created by the user (options[:selection_handler]) will be called with the selected row id as a parameter
      selection_link = ""
      if options[:direct_selection].blank? && options[:selection_handler].present? && options[:multi_selection].blank?
        selection_link = %Q/
        jQuery("##{id}_select_button").click( function(){ 
          var id = jQuery("##{id}").getGridParam('selrow'); 
          if (id) { 
            #{options[:selection_handler]}(id); 
          } else { 
            alert("Please select a row");
          }
          return false; 
        });/
      end

      # Enable direct selection (when a row in the table is clicked)
      # The javascript function created by the user (options[:selection_handler]) will be called with the selected row id as a parameter
      direct_link = ""
      if options[:direct_selection] && options[:selection_handler].present? && options[:multi_selection].blank?
        direct_link = %Q/
        onSelectRow: function(id){ 
          if(id){ 
            #{options[:selection_handler]}(id); 
          } 
        },/
      end

      # Enable grid_loaded callback
      # When data are loaded into the grid, call the Javascript function options[:grid_loaded] (defined by the user)
      grid_loaded = ""
      if options[:grid_loaded].present?
        grid_loaded = %Q/
        loadComplete: function(){ 
          #{options[:grid_loaded]}();
        },
        /
      end

      # Enable inline editing
      # When a row is selected, all fields are transformed to input types
      editable = ""
      if options[:edit] && options[:inline_edit] == 'true'
        editable = %Q/
        onSelectRow: function(id){ 
          if(id && id!==lastsel){ 
            jQuery('##{id}').restoreRow(lastsel);
            jQuery('##{id}').editRow(id, true, #{options[:inline_edit_handler]}, #{error_handler_name});
            lastsel=id; 
          } 
        },/
      end
      
      # Context menu
      # See http://www.trendskitchens.co.nz/jquery/contextmenu/
      # http://www.hard-bit.net/files/jqGrid-3.5/ContextMenu.html
      # http://www.hard-bit.net/blog/?p=171
      #
      context_menu = ""
      if options[:context_menu].size > 0 && !options[:context_menu][:menu_id].blank?
        context_menu = %Q/
        afterInsertRow: function(rowid, rowdata, rowelem){
          $('#' + rowid).contextMenu('#{options[:context_menu][:menu_id]}', #{options[:context_menu][:menu_bindings]});
        },/
      end           
      
      # Enable subgrids
      subgrid = ""
      subgrid_enabled = "subGrid:false,"

      if options[:subgrid].present?
        
        subgrid_enabled = "subGrid:true,"
        
        options[:subgrid] = 
          {
            :rows_per_page => '10',
            :sort_column   => 'id',
            :sort_order    => 'asc',
            :add           => 'false',
            :edit          => 'false',
            :delete        => 'false',
            :search        => 'false',
            :viewrecords   => 'true',
            :rowlist       => '[10,25,50,100]',
            :shrinkToFit   => 'false'
          }.merge(options[:subgrid])

        # Stringify options values
        options[:subgrid].inject({}) do |suboptions, (key, value)|
          suboptions[key] = value.to_s
          suboptions
        end
        
        subgrid_inline_edit = ""
        if options[:subgrid][:inline_edit] == true
          options[:subgrid][:edit] = 'false'
          subgrid_inline_edit = %Q/
          onSelectRow: function(id){ 
            if(id && id!==lastsel){ 
              jQuery('#'+subgrid_table_id).restoreRow(lastsel);
              jQuery('#'+subgrid_table_id).editRow(id,true); 
              lastsel=id; 
            } 
          },
          /
        end
          
        if options[:subgrid][:direct_selection] && options[:subgrid][:selection_handler].present?
          subgrid_direct_link = %Q/
          onSelectRow: function(id){ 
            if(id){ 
              #{options[:subgrid][:selection_handler]}(id); 
            } 
          },
          /
        end     
        
        sub_col_names, sub_col_model = gen_columns(options[:subgrid][:columns])
        
        subgrid = %Q~
        subGridRowExpanded: function(subgrid_id, row_id) {
        		var subgrid_table_id, pager_id;
        		subgrid_table_id = subgrid_id+"_t";
        		pager_id = "p_"+subgrid_table_id;
        		$("#"+subgrid_id).html("<table id='"+subgrid_table_id+"' class='scroll'></table><div id='"+pager_id+"' class='scroll'></div>");
        		var subgrd = jQuery("#"+subgrid_table_id).jqGrid({
        			url:"#{options[:subgrid][:url]}?q=2&id="+row_id,
              editurl:'#{options[:subgrid][:edit_url]}?parent_id='+row_id,                            
        			datatype: "json",
        			colNames: #{sub_col_names},
        			colModel: #{sub_col_model},
        		   	rowNum:#{options[:subgrid][:rows_per_page]},
        		   	pager: pager_id,
        		   	imgpath: '/images/jqgrid',
        		   	sortname: '#{options[:subgrid][:sort_column]}',
        		    sortorder: '#{options[:subgrid][:sort_order]}',
                viewrecords: #{options[:subgrid][:viewrecords]},
                rowlist: #{options[:subgrid][:rowlist]},
                shrinkToFit: #{options[:subgrid][:shrinkToFit]},
                toolbar : [true,"top"], 
        		    #{subgrid_inline_edit}
        		    #{subgrid_direct_link}
        		    height: '100%'
        		})
        		.navGrid("#"+pager_id,{edit:#{options[:subgrid][:edit]},add:#{options[:subgrid][:add]},del:#{options[:subgrid][:delete]},search:false})
            .navButtonAdd("#"+pager_id,{caption:"",title:$.jgrid.nav.searchtitle, buttonicon :'ui-icon-search', onClickButton:function(){ subgrd[0].toggleToolbar() } })
            subgrd.filterToolbar();
            subgrd[0].toggleToolbar();
        	},
        	subGridRowColapsed: function(subgrid_id, row_id) {
        	},
        ~
      end

      # Generate required Javascript & html to create the jqgrid
      %Q(
        <script type="text/javascript">
          #{error_handler_code}
          #{cookie_array}
          var lastsel;
          #{'jQuery(document).ready(function(){' unless options[:omit_ready]=='true'}
          var mygrid = jQuery("##{id}").jqGrid({
              url:'#{action}?q=1',
              editurl:'#{options[:edit_url]}',
              datatype: "json",
              colNames:#{col_names},
              colModel:#{col_model},
              pager: '##{id}_pager',
              pagerpos:'#{options[:pagerpos]}', 
              rowNum:#{options[:rows_per_page]},
              rowList:#{options[:rowlist]},
              imgpath: '/images/jqgrid',
              viewrecords:#{options[:viewrecords]},
              height: #{options[:height]},
              #{"sortname: '#{options[:sort_column]}'," unless options[:sort_column].blank?}
              #{"sortorder: '#{options[:sort_order]}'," unless options[:sort_order].blank?}
              gridview: #{options[:gridview]},
              scrollrows: true,
              autowidth: #{options[:autowidth]},
              loadui: '#{options[:loadui]}',
              rownumbers: #{options[:rownumbers]},
              hiddengrid: #{options[:hiddengrid]},
              hidegrid: #{options[:hidegrid]}, 
              shrinkToFit: #{options[:shrinkToFit]}, 
              #{multiselect}
              #{multiselect_handlers}
              #{masterdetails}
              #{grid_loaded}
              #{direct_link}
              #{editable}
              #{context_menu}
              #{subgrid_enabled}
              #{subgrid}
              caption: "#{title}"             
            })
            .navGrid('##{id}_pager',
              {edit:#{edit_button},add:#{options[:add]},del:#{options[:delete]},view:#{options[:view]},search:false,refresh:true},
              // Edit options
              {closeOnEscape:true,modal:true,recreateForm:#{options[:recreateForm]},width:#{options[:form_width]},closeAfterEdit:true,afterSubmit:function(r,data){return #{options[:error_handler_return_value]}(r,data,'edit');}},
              // Add options
              {closeOnEscape:true,modal:true,recreateForm:#{options[:recreateForm]},width:#{options[:form_width]},closeAfterAdd:true,afterSubmit:function(r,data){return #{options[:error_handler_return_value]}(r,data,'add');}},
              // Delete options
              {closeOnEscape:true,modal:true,afterSubmit:function(r,data){return #{options[:error_handler_return_value]}(r,data,'delete');}}
            )
            #{search}
            #{multihandler}
            #{selection_link}
            #{filter_toolbar}
          #{'})' unless options[:omit_ready]=='true'};
        </script>
        <div id="flash_alert" style="display:none;padding:0.7em;" class="ui-state-highlight ui-corner-all"></div>
        <table id="#{id}" class="scroll" cellpadding="0" cellspacing="0"></table>
        <div id="#{id}_pager" class="scroll" style="text-align:center;"></div>
      )
    end

    private
    
    def gen_columns(columns)
      # Generate columns data
      col_names = "[" # Labels
      col_model = "[" # Options
      columns.each do |c|
        col_names << "'#{c[:label]}',"
        col_model << "{name:'#{c[:field]}', index:'#{c[:field]}'#{get_attributes(c)}},"
      end
      col_names.chop! << "]"
      col_model.chop! << "]"
      [col_names, col_model]
    end

    # Generate a list of attributes for related column (align:'right', sortable:true, resizable:false, ...)
    def get_attributes(column)
      options = ","
      column.except(:field, :label).each do |couple|
        if couple[0] == :editoptions
          options << "editoptions:#{get_sub_options(couple[1])},"
        elsif couple[0] == :formatoptions
          options << "formatoptions:#{get_sub_options(couple[1])},"        
        elsif couple[0] == :formoptions
          options << "formoptions:#{get_sub_options(couple[1])},"
        elsif couple[0] == :searchoptions
          options << "searchoptions:#{get_sub_options(couple[1])},"
        elsif couple[0] == :editrules
          options << "editrules:#{get_sub_options(couple[1])},"
        else
          if couple[1].class == String
            options << "#{couple[0]}:'#{couple[1]}',"
          else
            options << "#{couple[0]}:#{couple[1]},"
          end
        end
      end
      options.chop!
    end

    # Generate options for editable fields (value, data, width, maxvalue, cols, rows, ...)
    def get_sub_options(editoptions)
      options = "{"
      editoptions.each do |couple|
        if couple[0] == :value # :value => [[1, "Rails"], [2, "Ruby"], [3, "jQuery"]]
          options << %Q/value:"/
          couple[1].each do |v|
            options << "#{v[0]}:#{v[1]};"
          end
          options.chop! << %Q/",/
        elsif couple[0] == :data # :data => [Category.all, :id, :title])
          options << %Q/value:"/
          couple[1].first.each do |obj|
            options << "%s:%s;" % [obj.send(couple[1].second), obj.send(couple[1].third)]
          end
          options.chop! << %Q/",/
        elsif couple[0] == :dataInit # :dataInit => %Q~{$(element).datepicker({onSelect: getDt(dateText, inst); }})}~
          options << %Q~#{couple[0]}:#{couple[1]},~
        elsif couple[0] == :elmsuffix || couple[0] == :elmpreffix # :elmsuffix => %Q~<a id="companysearch" href="javascript:void(0)"><span id="companysearchicon" class="ui-icon ui-icon-plus" style="position:absolute; top:2px; right:25px;"></span></a>~
          options << %Q~#{couple[0]}:'#{couple[1]}',~
        else # :size => 30, :rows => 5, :maxlength => 20, ...
          if couple[0] == :elmsuffix || couple[1].instance_of?(Fixnum) || couple[1] == 'true' || couple[1] == 'false' || couple[1] == true || couple[1] == false || couple[1] =~ /function/
              options << %Q/#{couple[0]}:#{couple[1]},/
            else
              options << %Q/#{couple[0]}:"#{couple[1]}",/          
          end
        end
      end
      options.chop! << "}"
    end 
end


module JqgridJson
  JSON_ESCAPE_MAP = {
    '\\'    => '\\\\',
    '</'    => '<\/',
    "\r\n"  => '\n',
    "\n"    => '\n',
    "\r"    => '\n',
    '"'     => '\\"' }
  
  def to_jqgrid_json(attributes, current_page, per_page, total)
    json = %Q({"page":"#{current_page}","total":#{total/per_page.to_i+1},"records":"#{total}")
    if total > 0
      json << %Q(,"rows":[)
      each do |elem|
        elem.id ||= index(elem)
        json << %Q({"id":"#{elem.id}","cell":[)
        couples = elem.attributes.symbolize_keys
        attributes.each do |atr|
          value = get_atr_value(elem, atr, couples)
          value = escape_json(value) if value and value.is_a? String
          json << %Q("#{value}",)
        end
        json.chop! << "]},"
      end
      json.chop! << "]}"
    else
      json << "}"
    end
  end
  
  private
    
  def escape_json(json)
    if json
      json.gsub(/(\\|<\/|\r\n|[\n\r"])/) { JSON_ESCAPE_MAP[$1] }
    else
      ''
    end
  end

  def get_atr_value(elem, atr, couples)
    if atr.instance_of?(String) && atr.to_s.include?('.')
      value = get_nested_atr_value(elem, atr.to_s.split('.').reverse) 
    else
      value = couples[atr]
      value = _resolve_value(atr, elem)
     # value = elem.send(atr.to_sym) if value.blank? && elem.respond_to?(atr) # Required for virtual attributes
    end
    value
  end
  def _resolve_value(value, record)
    case value
    when Symbol
      if record.respond_to?(value)
        record.send(value) 
      else 
        value.to_s
      end
    when Proc
      value.call(record)
    else
      value
    end
  end
  def get_nested_atr_value(elem, hierarchy)
    return nil if hierarchy.size == 0
    atr = hierarchy.pop
    raise ArgumentError, "#{atr} doesn't exist on #{elem.inspect}" unless elem.respond_to?(atr)
    nested_elem = elem.send(atr)
    return "" if nested_elem.nil?
    value = get_nested_atr_value(nested_elem, hierarchy)
    value.nil? ? nested_elem : value
  end
end

module JqgridFilter
  def filter_by_conditions(columns)
    conditions = ""
    columns.each do |column|
      conditions << "#{column} LIKE '%#{params[column]}%' AND " unless params[column].nil?
    end
    conditions.chomp("AND ")
  end
end