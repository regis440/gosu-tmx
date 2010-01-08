module TMX
  class Map
    autoload :TileCache, 'tmx/map/tile_cache'
    autoload :XMLLoader, 'tmx/map/xml_loader'
    
    include XMLLoader
    
    attr_reader :window
    
    attr_reader :properties
    attr_reader :width,      :height
    attr_reader :tile_width, :tile_height
    
    attr_reader :tile_sets, :layers, :object_groups
    
    DEFAULT_OPTIONS = {
      # Scales pixel units to tile units (if true) or user-defined scale (if
      # numeric) when passing them to callbacks.
      :scale_units => true,
      
      # Hooks for object, layer and tile set creation. Only on_object is
      # implemented so far.
      :on_tile_set => nil,
      :on_layer    => nil,
      :on_object   => nil,
      
      # This option discards all layer, object group and tile set info after
      # building the tile cache; uses less memory if you don't intend to
      # modify the map at run time.
      :discard_structure   => false,
      
      # These three options allow finer grained control of what to throw away
      # in case you intend to modify only certain aspects of the map.
      :discard_layer_info  => false,
      :discard_tile_info   => false,
      :discard_object_info => false,
    }
    
    def initialize window, file_name, options = {}
      options = DEFAULT_OPTIONS.merge options
      
      # TODO move this XML code to an external module
      # TODO allow file name or xml document?
      # TODO allow other map formats?
      
      mapdef = File.open(file_name) do |io|
        doc = Nokogiri::XML(io) { |conf| conf.noent.noblanks }
        
        # TODO figure out why this always fails
        # errors = doc.validate
        
        doc.root
      end
      
      # TODO proper version check; learn about TMX versions if there are any
      raise "Only version 1.0 maps are currently supported" unless mapdef['version']     == '1.0'
      raise "Only orthogonal maps are currently supported"  unless mapdef['orientation'] == 'orthogonal'
      
      @window = window
      @cache  = TileCache.new self
      
      @tile_width  = mapdef['tilewidth'].to_i
      @tile_height = mapdef['tileheight'].to_i
      
      @width  = mapdef['width'].to_i
      @height = mapdef['height'].to_i
      
      @scale_units = options[:scale_units] \
        ? 1.0 / [@tile_height, @tile_width].min \
        : false
      
      @properties = mapdef.tmx_parse_properties
      
      @tile_sets     = Hash[]
      @layers        = Hash[]
      @object_groups = Hash[]
      
      # callback for custom object creation
      @on_object = options[:on_object]
      
      mapdef.xpath('tileset').each do |xml|
        tile_set = parse_tile_set_def xml
        name     = tile_set.properties[:name]
        @tile_sets[name] = tile_set
      end
      
      mapdef.xpath('layer').each do |xml|
        layer = parse_layer_def xml
        name  = layer.properties[:name]
        @layers[name] = layer
      end # layers
      
      mapdef.xpath('objectgroup').each do |xml|
        group = parse_object_group_def xml
        name  = group.properties[:name]
        @object_groups[name] = group
      end # object groups
      
      @cache.rebuild!
      
      discard_structure = @properties.delete(:discard_structure)
      
      @layers        = nil if @properties.delete(:discard_layer_info)  || discard_structure
      @tile_sets     = nil if @properties.delete(:discard_tile_info)   || discard_structure
      @object_groups = nil if @properties.delete(:discard_object_info) || discard_structure
      
    end # initialize
    
    def create_tile_set name, file_name_or_images, properties
      raise NotImplementedError
    end
    
    def create_layer name, data, properties
      raise NotImplementedError
    end
    
    def create_object_group name, properties
      raise NotImplementedError
    end
    
    def draw x_off, y_off, z_off = 0, x_range = 0...@width, y_range = 0...@height
      @cache.draw x_off, y_off, z_off, x_range, y_range
    end
    
    protected
    
    def on_object name, group, properties
      if @on_object
        @on_object.call group, name, properties
      else
        properties
      end
    end # on_object
  end # Map
end
