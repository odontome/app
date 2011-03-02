FastGettext.add_text_domain 'app', :path => 'locale', :type => :po
FastGettext.default_available_locales = ['es'] #all you want to allow
FastGettext.default_text_domain = 'app'
FastGettext.locale = 'es'