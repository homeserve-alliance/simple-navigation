module SimpleNavigation
  # Represents an item in your navigation.
  # Gets generated by the item method in the config-file.
  class Item
    attr_reader :key,
                :name,
                :sub_navigation,
                :url

    # see ItemContainer#item
    #
    # The subnavigation (if any) is either provided by a block or
    # passed in directly as <tt>items</tt>
    def initialize(container, key, name, url = nil, opts = {}, &sub_nav_block)
      self.container = container
      self.key = key
      self.name = name.respond_to?(:call) ? name.call : name
      self.url =  url.respond_to?(:call) ? url.call : url
      self.options = opts

      setup_sub_navigation(options[:items], &sub_nav_block)
    end

    # Returns the item's name.
    # If :apply_generator option is set to true (default),
    # the name will be passed to the name_generator specified
    # in the configuration.
    #
    def name(options = {})
      options = { apply_generator: true }.merge(options)
      if options[:apply_generator]
        config.name_generator.call(@name, self)
      else
        @name
      end
    end

    # Returns true if this navigation item should be rendered as 'selected'.
    # An item is selected if
    #
    # * it has a subnavigation and one of its subnavigation items is selected or
    # * its url matches the url of the current request (auto highlighting)
    #
    def selected?
      @selected ||= selected_by_subnav? || selected_by_condition?
    end

    # Returns the html-options hash for the item, i.e. the options specified
    # for this item in the config-file.
    # It also adds the 'selected' class to the list of classes if necessary.
    def html_options
      html_opts = options.fetch(:html) { Hash.new }
      html_opts[:id] ||= autogenerated_item_id

      classes = [html_opts[:class], selected_class, active_leaf_class]
      classes = classes.flatten.compact.join(' ')
      html_opts[:class] = classes if classes && !classes.empty?

      html_opts
    end

    # Returns the configured active_leaf_class if the item is the selected leaf,
    # nil otherwise
    def active_leaf_class
      if !selected_by_subnav? && selected_by_condition?
        config.active_leaf_class
      end
    end

    # Returns the configured selected_class if the item is selected,
    # nil otherwise
    def selected_class
      if selected?
        container.selected_class || config.selected_class
      end
    end

    # Returns the :highlights_on option as set at initialization
    def highlights_on
      @highlights_on ||= options[:highlights_on]
    end

    # Returns the :method option as set at initialization
    def method
      @method ||= options[:method]
    end

    # Returns the html attributes for the link as set with the :link_html option
    # at initialization
    def link_html_options
      @link_html_options ||= options[:link_html]
    end

    def fetch(compound_key, &blk)
      k, dot, rest = compound_key.to_s.partition('.')
      return unless k == key.to_s
      if rest.size.zero?
        if block_given?
          blk.call(self)
        else
          return self
        end
      else
        return if sub_navigation.nil?
        sub_navigation.fetch(rest, &blk)
      end
    end

    def store(compound_key, item, &blk)
      k, dot, rest = compound_key.to_s.partition('.')
      return false unless k == key.to_s
      @sub_navigation ||= ItemContainer.new(container.level + 1)
      @sub_navigation.store(rest, item, &blk)
    end

    protected

    # Returns true if item has a subnavigation and
    # the sub_navigation is selected
    def selected_by_subnav?
      sub_navigation && sub_navigation.selected?
    end

    # Returns true if the item's url matches the request's current url.
    def selected_by_condition?
      highlights_on ? selected_by_highlights_on? : selected_by_autohighlight?
    end

    # Returns true if both the item's url and the request's url are root_path
    def root_path_match?
      url == '/' && SimpleNavigation.request_path == '/'
    end

    # Returns the item's id which is added to the rendered output.
    def autogenerated_item_id
      config.id_generator.call(key) if config.autogenerate_item_ids
    end

    # Return true if auto_highlight is on for this item.
    def auto_highlight?
      config.auto_highlight && container.auto_highlight
    end

    def url_without_anchor
      url && url.split('#').first
    end

    private

    attr_accessor :container,
                  :options

    attr_writer :key,
                :name,
                :sub_navigation,
                :url

    def config
      SimpleNavigation.config
    end

    def request_uri
      SimpleNavigation.request_uri
    end

    def selected_by_autohighlight?
      return false unless auto_highlight?
      root_path_match? ||
      SimpleNavigation.current_page?(url_without_anchor) ||
      autohighlight_by_subpath?
    end

    def autohighlight_by_subpath?
      SimpleNavigation.config.highlight_on_subpath && selected_by_subpath?
    end

    def selected_by_highlights_on?
      case highlights_on
      when Regexp then !!(request_uri =~ highlights_on)
      when Proc then highlights_on.call
      when :subpath then selected_by_subpath?
      else
        fail ArgumentError, ':highlights_on must be a Regexp, Proc or :subpath'
      end
    end

    def selected_by_subpath?
      escaped_url = Regexp.escape(url_without_anchor)
      !!(request_uri =~ /^#{escaped_url}(\/|$|\?)/i)
    end

    def setup_sub_navigation(items = nil, &sub_nav_block)
      return unless sub_nav_block || items

      self.sub_navigation = ItemContainer.new(container.level + 1)

      if sub_nav_block
        sub_nav_block.call sub_navigation
      else
        sub_navigation.items = items
      end
    end
  end
end
