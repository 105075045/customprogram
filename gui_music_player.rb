require 'rubygems'
require 'gosu'


class Track
  attr_accessor :name, :location, :duration
  def initialize(name, location, duration)
    @name     = name
    @location = Gosu::Song.new(location) 
    @duration = duration                  
  end
end

class Album
  attr_accessor :title, :artist, :genre, :image, :tracks, :track_count

  def initialize(artist, title, image_path, genre, tracks, track_count)
    @artist      = artist
    @title       = title
    @genre       = genre
    @image       = Gosu::Image.new(image_path)
    @tracks      = tracks
    @track_count = track_count
  end
end


module ZOrder
  BACKGROUND = 0
  PLAYER     = 1
  UI         = 2
end


module Genre
  J_POP       = 1
  VOCALOID    = 2
  POP         = 3
  Anime       = 4
  Game        = 5
  Elden_Ring  = 6
  Classical   = 7
  Ado         = 8
end

GENRE_NAMES = ['Null', 'J_Pop', 'Vocaloid', 'Pop', 'Anime', 'Game', 'Elden_Ring', 'Classical', 'Ado']

class MusicPlayerMain < Gosu::Window
  HEADER_H         = 230
  ROW_H            = 135
  TRACK_ROW_HEIGHT = 100
  PLAYLIST_MAX     = 8

  
  def initialize
    super(2000, 1180, false)
    self.caption = 'Music Player'

    # Layout & colors
    @sidebar_x = 20
    @sidebar_y = 20
    @sidebar_w = 320
    @sidebar_color = Gosu::Color.new(255, 18, 18, 18)

    @main_panel_alpha_top = 110
    @main_panel_alpha_bot = 230
    @playbar_h            = 90

    # Data
    @album_array  = read_albums('album.txt')
    @album_number = @album_array.length

    # Fonts
    @mouse_font          = Gosu::Font.new(25)
    @track_font          = Gosu::Font.new(28)
    @sidebar_title_font  = Gosu::Font.new(28)
    @sidebar_meta_font   = Gosu::Font.new(22)
    @status_font         = Gosu::Font.new(22)

    # Selection & playback state
    @track_print          = nil                # which album index is selected (sidebar click)
    @song                 = nil                
    @current_track_name   = nil
    @current_album_index  = nil
    @current_track_index  = nil
    @scroll_y             = 0

    # Playlist state
    @playlist                = []             # array of { album: int, track: int, name: str }
    @show_playlist           = false
    @playlist_selected_index = nil

    # Toast state
    @toast_text       = nil
    @toast_expires_at = 0.0

    # Images
    @playlist_icon = safe_load_image('playlist.png')
    @img_prev      = safe_load_image('previous.png')
    @img_next      = safe_load_image('next.png')
    @img_play      = safe_load_image('play.png')
    @img_stop      = safe_load_image('stop.png')
    @img_shuffle   = safe_load_image('shuffle.png')
    @img_plus      = safe_load_image('plus.png')
    @img_delete    = safe_load_image('delete.png')

    # Control hit-areas (rebuilt each draw)
    @controls = []
  end




  def safe_load_image(path)
    image = nil
    begin
      image = Gosu::Image.new(path)
    rescue
      image = nil
    end
    return image
  end

  def in_range?(value, lo, hi)
    if value >= lo && value <= hi
      return true
    else
      return false
    end
  end

  def point_in_rect?(px, py, rect)
    left_ok   = px >= rect[:x]
    right_ok  = px <= rect[:x] + rect[:w]
    top_ok    = py >= rect[:y]
    bottom_ok = py <= rect[:y] + rect[:h]
    if left_ok && right_ok && top_ok && bottom_ok
      return true
    else
      return false
    end
  end

  def safe_text(s)
    if s.nil?
      return ''
    else
      return s.to_s.strip
    end
  end

  def show_toast(message, seconds = 1.6)
    @toast_text = message
    @toast_expires_at = Gosu.milliseconds / 1000.0 + seconds
    return nil
  end



  def read_albums(file_path)
    file = File.new(file_path, 'r')
    count = file.gets.to_i
    array = Array.new(count)

    i = 0
    while i < count
      array[i] = read_album(file)
      i = i + 1
    end

    file.close
    return array
  end

  def read_album(file)
    artist      = file.gets
    title       = file.gets
    image_path  = file.gets.chomp
    genre       = file.gets.to_i
    track_count = file.gets.to_i
    tracks      = read_tracks(file, track_count)
    album       = Album.new(artist, title, image_path, genre, tracks, track_count)
    return album
  end

  def read_tracks(file, n)
    tracks = Array.new(n)
    i = 0
    while i < n
      name     = file.gets
      location = file.gets.chomp
      duration = file.gets
      tracks[i] = Track.new(name, location, duration)
      i = i + 1
    end
    return tracks
  end



  def header_rect
    rect = {}
    rect[:x] = @sidebar_x
    rect[:y] = @sidebar_y
    rect[:w] = @sidebar_w
    rect[:h] = HEADER_H
    return rect
  end

  def right_panel_layout(album)
    panel_x = @sidebar_x + @sidebar_w + 20
    panel_w = width - panel_x - 20
    top_y   = 40

    cover_size = 220
    if album != nil && album.image != nil
      header_bottom = top_y + cover_size
    else
      header_bottom = top_y + 150
    end

    table_top   = header_bottom + 28
    first_row_y = table_top + @sidebar_meta_font.height + 12

    layout = {}
    layout[:panel_x]      = panel_x
    layout[:panel_w]      = panel_w
    layout[:top_y]        = top_y
    layout[:cover_size]   = cover_size
    layout[:header_bottom]= header_bottom
    layout[:table_top]    = table_top
    layout[:first_row_y]  = first_row_y
    layout[:col_num]      = panel_x + 10
    layout[:col_title]    = panel_x + 60
    layout[:col_artist]   = panel_x + 520
    layout[:col_duration] = panel_x + panel_w - 70
    return layout
  end

  # Push playlist header down (no album art on the right)
  def playlist_table_positions
    layout = right_panel_layout(nil)
    gap_from_top = 220
    table_top    = layout[:top_y] + gap_from_top
    first_row_y  = table_top + @sidebar_meta_font.height + 12
    return [layout, table_top, first_row_y]
  end

  def format_duration(raw)
    s = safe_text(raw)
    if s.include?(':')
      return s
    end
    total = s.to_i
    minutes = total / 60
    seconds = total % 60
    return '%d:%02d' % [minutes, seconds]
  end


  # ===================== DRAWING ===================


  def draw_background
    Gosu.draw_rect(0, 0, width, height, Gosu::Color::BLACK, ZOrder::BACKGROUND)
    return nil
  end

  # ----- left header (playlist icon + label) -----
  def draw_sidebar_header
    r = header_rect
    Gosu.draw_rect(r[:x], r[:y], r[:w], r[:h], Gosu::Color.rgba(255, 255, 255, 8), ZOrder::BACKGROUND)

    if @playlist_icon != nil
      pad = 18
      total_w = r[:w] - pad * 2
      total_h = r[:h] - pad * 2

      label_gap   = 34
      icon_height = total_h - label_gap

      sx = total_w / @playlist_icon.width.to_f
      sy = icon_height / @playlist_icon.height.to_f

      scale = sx
      if sy < sx
        scale = sy
      end
      scale = scale * 0.90

      draw_w = (@playlist_icon.width  * scale).round
      draw_h = (@playlist_icon.height * scale).round
      draw_x = r[:x] + (r[:w] - draw_w) / 2
      draw_y = r[:y] + ((icon_height - draw_h) / 2)

      @playlist_icon.draw(draw_x, draw_y, ZOrder::UI, scale, scale)

      label = 'Playlists'
      label_scale = 1.2
      label_w = @sidebar_title_font.text_width(label) * label_scale
      label_x = r[:x] + (r[:w] - label_w) / 2
      label_y = r[:y] + icon_height + (label_gap - @sidebar_title_font.height * label_scale) / 2
      @sidebar_title_font.draw(label, label_x, label_y, ZOrder::UI, label_scale, label_scale, Gosu::Color::WHITE)
    end

    return nil
  end

  # ----- album list below header (with scrollbar) -----
  def draw_sidebar_album_list
    list_x = @sidebar_x + 10
    list_y = @sidebar_y + HEADER_H
    list_w = @sidebar_w - 20
    list_h = height - @sidebar_y - list_y - 90

    content_h  = @album_array.length * ROW_H
    max_scroll = content_h - list_h
    if max_scroll < 0
      max_scroll = 0
    end

    if @scroll_y < 0
      @scroll_y = 0
    end
    if @scroll_y > max_scroll
      @scroll_y = max_scroll
    end

    clip_to(list_x, list_y, list_w, list_h) do
      i = 0
      while i < @album_array.length
        album = @album_array[i]
        if album == nil
          break
        end

        row_y = list_y + i * ROW_H - @scroll_y

        thumb_w = 100
        thumb_h = 100
        Gosu.draw_rect(list_x, row_y , thumb_w, thumb_h, Gosu::Color.rgba(255, 255, 255, 18), ZOrder::UI)

        if album.image != nil
          sx = thumb_w / album.image.width.to_f
          sy = thumb_h / album.image.height.to_f
          album.image.draw(list_x, row_y , ZOrder::UI, sx, sy)
        end

        text_x     = list_x + thumb_w + 20
        genre_name = GENRE_NAMES[album.genre.to_i]
        if genre_name == nil
          genre_name = 'Unknown'
        end

        @sidebar_title_font.draw(genre_name, text_x, row_y + 10, ZOrder::PLAYER, 1, 1, Gosu::Color::WHITE)
        @sidebar_meta_font.draw(safe_text(album.title), text_x, row_y + 10 + @sidebar_title_font.height + 4, ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)

        i = i + 1
      end
    end

    # Scrollbar
    rail_w = 6
    rail_x = @sidebar_x + @sidebar_w - 6 - rail_w
    rail_y = list_y
    rail_h = list_h
    Gosu.draw_rect(rail_x, rail_y, rail_w, rail_h, Gosu::Color.rgba(128, 128, 128, 60), ZOrder::UI)

    if content_h > list_h && list_h > 0
      thumb_h = (rail_h * (list_h.to_f / content_h)).to_i
      if thumb_h < 20
        thumb_h = 20
      end

      if max_scroll == 0
        scroll_ratio = 0.0
      else
        scroll_ratio = @scroll_y.to_f / max_scroll
      end

      thumb_y = rail_y + (rail_h - thumb_h) * scroll_ratio
      Gosu.draw_rect(rail_x, thumb_y, rail_w, thumb_h, Gosu::Color.rgba(128, 128, 128, 200), ZOrder::UI)
    end

    return nil
  end

  # ----- right panel (album tracks) -----
  def print_tracks(album_index)
    if album_index == nil
      return nil
    end
    if @show_playlist == true
      return nil
    end

    album = @album_array[album_index]
    if album == nil
      return nil
    end

    layout = right_panel_layout(album)

    panel_x    = layout[:panel_x]
    panel_w    = layout[:panel_w]
    y          = layout[:top_y]
    cover_size = layout[:cover_size]

    if album.image != nil
      sx = cover_size / album.image.width.to_f
      sy = cover_size / album.image.height.to_f
      scale = sx
      if sy < sx
        scale = sy
      end
      album.image.draw(panel_x, y, ZOrder::PLAYER, scale, scale)
      text_left = panel_x + cover_size + 24
    else
      text_left = panel_x
    end

    title  = safe_text(album.title)
    artist = safe_text(album.artist)
    if artist == ''
      artist = 'Various Artists'
    end
    genre_name = GENRE_NAMES[album.genre.to_i]
    if genre_name == nil
      genre_name = 'Unknown'
    end

    @sidebar_title_font.draw((title == '' ? '(Untitled Album)' : title), text_left, y + 0, ZOrder::PLAYER, 1.15, 1.15, Gosu::Color::WHITE)
    meta_y = y + 0 + (@sidebar_title_font.height * 1.15) + 8
    @sidebar_meta_font.draw("#{artist}  •  #{genre_name}", text_left, meta_y, ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)

    Gosu.draw_rect(panel_x, layout[:header_bottom] + 12, panel_w, 1, Gosu::Color.rgba(255, 255, 255, 25), ZOrder::PLAYER)

    @sidebar_meta_font.draw('#',      layout[:col_num],      layout[:table_top], ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)
    @sidebar_meta_font.draw('Track',  layout[:col_title],    layout[:table_top], ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)
    @sidebar_meta_font.draw('Artist', layout[:col_artist],   layout[:table_top], ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)
    @sidebar_meta_font.draw('Time',   layout[:col_duration], layout[:table_top], ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)

    row_y = layout[:first_row_y]
    i = 0
    while i < album.track_count
      t = album.tracks[i]
      name = ''
      dur  = ''
      if t != nil
        name = safe_text(t.name)
        dur  = format_duration(t.duration)
      end

      @sidebar_meta_font.draw((i + 1).to_s, layout[:col_num], row_y, ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)
      @track_font.draw((name == '' ? 'Untitled' : name), layout[:col_title], row_y, ZOrder::PLAYER, 1.05, 1.05, Gosu::Color::WHITE)
      @sidebar_meta_font.draw(artist, layout[:col_artist], row_y + 4, ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)
      @sidebar_meta_font.draw(dur,    layout[:col_duration], row_y + 4, ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)

      row_y = row_y + TRACK_ROW_HEIGHT
      i = i + 1
    end

    Gosu.draw_rect(panel_x, row_y - 14, panel_w, 1, Gosu::Color.rgba(255, 255, 255, 20), ZOrder::PLAYER)
    return nil
  end

  # ----- right panel (playlist view) -----
  def draw_playlist_panel
    if @show_playlist == false
      return nil
    end

    layout_and_tops = playlist_table_positions
    layout     = layout_and_tops[0]
    table_top  = layout_and_tops[1]
    first_row  = layout_and_tops[2]

    panel_x = layout[:panel_x]

    # Title & helper line
    @sidebar_title_font.draw("Playlist (#{@playlist.length}/#{PLAYLIST_MAX})", panel_x, layout[:top_y] + 4, ZOrder::PLAYER, 1.35, 1.35, Gosu::Color::WHITE)
    helper_y = layout[:top_y] + 4 + (@sidebar_title_font.height * 1.35) + 6
    @sidebar_meta_font.draw('Click a row to play/pause. Use Delete to remove.', panel_x, helper_y, ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)

    # Divider + headers
    Gosu.draw_rect(panel_x, table_top - 12, layout[:panel_w], 1, Gosu::Color.rgba(255, 255, 255, 25), ZOrder::PLAYER)
    @sidebar_meta_font.draw('#',      layout[:col_num],      table_top, ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)
    @sidebar_meta_font.draw('Track',  layout[:col_title],    table_top, ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)
    @sidebar_meta_font.draw('Album',  layout[:col_artist],   table_top, ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)
    @sidebar_meta_font.draw('Time',   layout[:col_duration], table_top, ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)

    # Rows (clickable, no tint)
    row_y = first_row
    i = 0
    while i < @playlist.length
      item  = @playlist[i]
      album = nil
      track = nil

      if item != nil
        album = @album_array[item[:album]]
        if album != nil
          track = album.tracks[item[:track]]
        end
      end

      track_name = '(missing)'
      album_name = '(missing)'
      duration   = ''

      if track != nil
        track_name = safe_text(track.name)
        duration   = format_duration(track.duration)
      end
      if album != nil
        album_name = safe_text(album.title)
      end

      @sidebar_meta_font.draw((i + 1).to_s, layout[:col_num], row_y, ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)
      @track_font.draw(track_name,          layout[:col_title],    row_y, ZOrder::PLAYER, 1.08, 1.08, Gosu::Color::WHITE)
      @sidebar_meta_font.draw(album_name,   layout[:col_artist],   row_y + 4, ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)
      @sidebar_meta_font.draw(duration,     layout[:col_duration], row_y + 4, ZOrder::PLAYER, 1, 1, Gosu::Color::GRAY)

      row_y = row_y + TRACK_ROW_HEIGHT
      i = i + 1
    end

    return nil
  end

  # ----- playbar status text -----
  def draw_play_status
    if @song == nil || @current_track_name == nil
      return nil
    end

    label = ''
    color = Gosu::Color::GRAY
    if @song.playing?
      label = 'Now Playing: ' + @current_track_name.to_s.strip
      color = Gosu::Color::WHITE
    else
      label = 'Song Pause: ' + @current_track_name.to_s.strip
      color = Gosu::Color::WHITE
    end

    x = 16
    y = 1120
    @status_font.draw(label, x, y, 10_003, 1.3, 1.3, color)
    return nil
  end

  def draw_mouse_position
    label_x = width - 260
    label_y = height - @playbar_h - 44
    @mouse_font.draw('mouse_x: ' + mouse_x.to_s, label_x, label_y, ZOrder::PLAYER, 1, 1, Gosu::Color::WHITE)
    @mouse_font.draw('mouse_y: ' + mouse_y.to_s, label_x, label_y + 22, ZOrder::PLAYER, 1, 1, Gosu::Color::WHITE)
    return nil
  end

  # ----- toast -----
  def draw_toast
    if @toast_text == nil
      return nil
    end
    now = Gosu.milliseconds / 1000.0
    if now <= @toast_expires_at
      y = 1120
      @status_font.draw(@toast_text, 1715, y, 10_005, 1.3, 1.3, Gosu::Color::WHITE)
    else
      @toast_text = nil
    end
    return nil
  end

  # ----- buttons (plus/delete, prev, play/stop, next, shuffle) -----
  def draw_controls
    @controls = []  

    target   = 54.0
    center_y = height - (@playbar_h / 2.0)
    top_y    = (center_y - target / 2.0).to_i
    spacing  = 88
    start_x  = (width / 2) - (spacing * 2)

    playing_now = false
    if @song != nil && @song.playing?
      playing_now = true
    end

    # Slot 1: plus (album) or delete (playlist)
    if @show_playlist == true
      if @img_delete != nil
        scale = target / @img_delete.width
        @img_delete.draw(start_x, top_y, 10_004, scale, scale)
        @controls << { name: :delete_selected, x: start_x, y: top_y, w: target, h: target }
      end
    else
      if @img_plus != nil
        scale = target / @img_plus.width
        @img_plus.draw(start_x, top_y, 10_004, scale, scale)
        @controls <<({ name: :add, x: start_x, y: top_y, w: target, h: target })
      end
    end

    cursor_x = start_x + spacing

    if @img_prev != nil
      s = target / @img_prev.width
      @img_prev.draw(cursor_x, top_y, 10_004, s, s)
      @controls <<({ name: :previous, x: cursor_x, y: top_y, w: target, h: target })
    end
    cursor_x = cursor_x + spacing

    if playing_now == true
      if @img_stop != nil
        s = target / @img_stop.width
        @img_stop.draw(cursor_x, top_y, 10_004, s, s)
        @controls <<({ name: :stop, x: cursor_x, y: top_y, w: target, h: target })
      end
    else
      if @img_play != nil
        s = target / @img_play.width
        @img_play.draw(cursor_x, top_y, 10_004, s, s)
        @controls <<({ name: :play, x: cursor_x, y: top_y, w: target, h: target })
      end
    end
    cursor_x = cursor_x + spacing

    if @img_next != nil
      s = target / @img_next.width
      @img_next.draw(cursor_x, top_y, 10_004, s, s)
      @controls <<({ name: :next, x: cursor_x, y: top_y, w: target, h: target })
    end
    cursor_x = cursor_x + spacing

    if @img_shuffle != nil
      s = target / @img_shuffle.width
      @img_shuffle.draw(cursor_x, top_y, 10_004, s, s)
      @controls <<({ name: :shuffle, x: cursor_x, y: top_y, w: target, h: target })
    end

    return nil
  end

  def handle_transport_click(x, y)
    i = 0
    while i < @controls.length
      r = @controls[i]
      if point_in_rect?(x, y, r) == true
        case r[:name]
        when :previous
          if @show_playlist == true && @playlist.length > 0
            previous_playlist_track
          else
            previous_track
          end
        when :next
          if @show_playlist == true && @playlist.length > 0
            next_playlist_track
          else
            next_track
          end
        when :play
          press_play
        when :stop
          press_stop
        when :shuffle
          if @show_playlist == true && @playlist.length > 0
            shuffle_playlist_track
          else
            shuffle_track
          end
        when :add
          add_current_to_playlist
        when :delete_selected
          delete_selected_playlist_row
        end
        return true
      end
      i = i + 1
    end
    return false
  end


  # =================== HIT TESTING =================


  def get_album_clicked(x, y)
    list_x = @sidebar_x + 10
    list_y = @sidebar_y + HEADER_H
    list_w = @sidebar_w - 20

    if in_range?(x, list_x, list_x + list_w) == false
      return nil
    end

    adjusted_y = y + @scroll_y
    if adjusted_y < list_y
      return nil
    end

    idx = ((adjusted_y - list_y) / ROW_H).to_i
    if idx >= 0 && idx <= @album_array.length - 1
      return idx
    else
      return nil
    end
  end

  def get_track_clicked(x, y, album)
    if album == nil
      return nil
    end
    if @show_playlist == true
      return nil
    end

    layout = right_panel_layout(album)

    x_ok = in_range?(x, layout[:panel_x], layout[:panel_x] + layout[:panel_w])
    y_ok = (y >= layout[:first_row_y])

    if x_ok == false || y_ok == false
      return nil
    end

    idx = ((y - layout[:first_row_y]) / TRACK_ROW_HEIGHT).floor
    if idx >= 0 && idx <= album.track_count - 1
      return idx
    else
      return nil
    end
  end

  def get_playlist_row_clicked(x, y)
    if @show_playlist == false
      return nil
    end

    result = playlist_table_positions
    layout     = result[0]
    first_row  = result[2]

    in_x = in_range?(x, layout[:panel_x], layout[:panel_x] + layout[:panel_w])
    in_y = (y >= first_row)

    if in_x == false || in_y == false
      return nil
    end

    idx = ((y - first_row) / TRACK_ROW_HEIGHT).floor
    if idx >= 0 && idx < @playlist.length
      return idx
    else
      return nil
    end
  end

  # ==================== PLAYBACK ===================

  def ensure_album_selection
    if @track_print == nil
      if @album_array.length == 0
        return false
      else
        @track_print = 0
      end
    end
    return true
  end

  def set_current_from_album_track(album_index, track_index)
    @current_album_index = album_index
    @current_track_index = track_index
    @current_track_name  = @album_array[album_index].tracks[track_index].name
    return nil
  end

  def play_track(album_index, track_index)
    album = @album_array[album_index]
    if album == nil
      return nil
    end
    track = album.tracks[track_index]
    if track == nil
      return nil
    end
    song = track.location
    if song == nil
      return nil
    end

    set_current_from_album_track(album_index, track_index)

    if @song == song
      if @song.playing?
        @song.pause
      else
        @song.play
      end
    else
      if @song != nil
        @song.stop
      end
      @song = song
      @song.play
    end

    return nil
  end


  def press_play
    # Playlist mode first
    if @show_playlist == true && @playlist.length > 0
      if @song != nil && @song.playing? == false
        @song.play
        return nil
      end
      if @playlist_selected_index == nil
        @playlist_selected_index = 0
      end
      item = @playlist[@playlist_selected_index]
      play_track(item[:album], item[:track])
      return nil
    end

    # Album mode
    if ensure_album_selection == false
      return nil
    end
    album = @album_array[@track_print]
    if album == nil || album.track_count <= 0
      return nil
    end

    # Resume same album if paused
    if @song != nil && @song.playing? == false && @current_album_index == @track_print
      @song.play
      return nil
    end

    if @current_album_index != @track_print
      @current_album_index = @track_print
      @current_track_index = nil
    end
    if @current_track_index == nil
      @current_track_index = 0
    end
    play_track(@current_album_index, @current_track_index)
    return nil
  end

  def press_stop
    if @song != nil && @song.playing? == true
      @song.pause
    end
    return nil
  end

  def next_track
    if ensure_album_selection == false
      return nil
    end
    album = @album_array[@track_print]
    if album == nil || album.track_count <= 0
      return nil
    end

    @current_album_index = @track_print
    if @current_track_index == nil
      @current_track_index = 0
    else
      @current_track_index = @current_track_index + 1
      if @current_track_index >= album.track_count
        @current_track_index = 0
      end
    end

    play_track(@current_album_index, @current_track_index)
    return nil
  end

  def previous_track
    if ensure_album_selection == false
      return nil
    end
    album = @album_array[@track_print]
    if album == nil || album.track_count <= 0
      return nil
    end

    @current_album_index = @track_print
    if @current_track_index == nil
      @current_track_index = 0
    else
      @current_track_index = @current_track_index - 1
      if @current_track_index < 0
        @current_track_index = album.track_count - 1
      end
    end

    play_track(@current_album_index, @current_track_index)
    return nil
  end

  def shuffle_track
    if ensure_album_selection == false
      return nil
    end
    album = @album_array[@track_print]
    if album == nil || album.track_count <= 0
      return nil
    end

    @current_album_index = @track_print
    new_index = rand(album.track_count)

    if album.track_count > 1 && @current_track_index != nil
      while new_index == @current_track_index
        new_index = rand(album.track_count)
      end
    end

    @current_track_index = new_index
    play_track(@current_album_index, @current_track_index)
    return nil
  end

  # -----Playbar button -----
  def next_playlist_track
    if @playlist.length == 0
      return nil
    end
    if @playlist_selected_index == nil
      @playlist_selected_index = 0
    else
      @playlist_selected_index = @playlist_selected_index + 1
      if @playlist_selected_index >= @playlist.length
        @playlist_selected_index = 0
      end
    end
    it = @playlist[@playlist_selected_index]
    play_track(it[:album], it[:track])
    return nil
  end

  def previous_playlist_track
    if @playlist.length == 0
      return nil
    end
    if @playlist_selected_index == nil
      @playlist_selected_index = 0
    else
      @playlist_selected_index = @playlist_selected_index - 1
      if @playlist_selected_index < 0
        @playlist_selected_index = @playlist.length - 1
      end
    end
    it = @playlist[@playlist_selected_index]
    play_track(it[:album], it[:track])
    return nil
  end

  def shuffle_playlist_track
    if @playlist.length == 0
      return nil
    end
    new_i = rand(@playlist.length)
    if @playlist.length > 1 && @playlist_selected_index != nil
      while new_i == @playlist_selected_index
        new_i = rand(@playlist.length)
      end
    end
    @playlist_selected_index = new_i
    it = @playlist[@playlist_selected_index]
    play_track(it[:album], it[:track])
    return nil
  end

  # ----- playlist CRUD -----
  def add_current_to_playlist
    if @playlist.length >= PLAYLIST_MAX
      show_toast('Playlist full (max ' + PLAYLIST_MAX.to_s + ')')
      return nil
    end

    ai = @current_album_index
    ti = @current_track_index

    if ai == nil || ti == nil
      if @track_print != nil && @album_array[@track_print] != nil && @album_array[@track_print].track_count > 0
        ai = @track_print
        ti = 0
      else
        show_toast('No track to add')
        return nil
      end
    end

    # anti-dup check
    i = 0
    while i < @playlist.length
      itm = @playlist[i]
      if itm[:album] == ai && itm[:track] == ti
        show_toast('Track already added')
        return nil
      end
      i = i + 1
    end

    album = @album_array[ai]
    track = nil
    if album != nil
      track = album.tracks[ti]
    end
    name = '(Untitled)'
    if track != nil
      name = safe_text(track.name)
      if name == ''
        name = '(Untitled)'
      end
    end

    @playlist << { album: ai, track: ti, name: name }
    @playlist_selected_index = @playlist.length - 1
    show_toast('Added to playlist')
    return nil
  end

  def delete_selected_playlist_row
  if @show_playlist == false
    show_toast('Open playlist to delete')
    return nil
  end

  if @playlist_selected_index == nil
    show_toast('No selection')
    return nil
  end

  # Grab the item  about to delete
  item = @playlist[@playlist_selected_index]

  if item != nil
    ai = item[:album]
    ti = item[:track]

    album = @album_array[ai]
    track = (album != nil ? album.tracks[ti] : nil)

    # stop the currently playing track
    if track != nil && @song != nil && track.location == @song
      @song.stop
      @current_album_index = nil
      @current_track_index = nil
      @current_track_name  = nil
    end
  end

  # Remove the row
  @playlist.delete_at(@playlist_selected_index)

  # Fix selection after deletion
  if @playlist_selected_index >= @playlist.length
    @playlist_selected_index = @playlist.length - 1
  end

  show_toast('Removed from playlist')
  return nil
end


  # ==================== MAIN DRAW ==================


  def draw
    draw_background

    Gosu.draw_rect(@sidebar_x, @sidebar_y, @sidebar_w, height - @sidebar_y, @sidebar_color, ZOrder::BACKGROUND)
    draw_sidebar_header
    draw_sidebar_album_list

    # Right gradient
    panel_x = @sidebar_x + @sidebar_w + 20
    panel_y = 20
    panel_w = width - panel_x - 20
    playbar_y = height - @playbar_h
    panel_h_to_bar = playbar_y - panel_y

    if panel_w > 0 && panel_h_to_bar > 0
      steps  = 100
      step_h = panel_h_to_bar.to_f / steps
      i = 0
      while i < steps
        t = i.to_f / (steps - 1)

        r1 = 30; g1 = 120; b1 = 255; a1 = @main_panel_alpha_top
        r2 = 0;  g2 = 0;   b2 = 0;   a2 = @main_panel_alpha_bot

        r = (r1 + (r2 - r1) * t).round
        g = (g1 + (g2 - g1) * t).round
        b = (b1 + (b2 - b1) * t).round
        a = (a1 + (a2 - a1) * t).round

        y = panel_y + i * step_h
        h = step_h
        if i == steps - 1
          h = (panel_y + panel_h_to_bar - y)
        end

        Gosu.draw_rect(panel_x, y, panel_w, h, Gosu::Color.rgba(r, g, b, a), ZOrder::BACKGROUND)
        i = i + 1
      end
    end

    # Content
    print_tracks(@track_print)
    draw_playlist_panel
    draw_mouse_position

    # Playbar surface
    Gosu.draw_rect(0, playbar_y - 1, width, @playbar_h + 2, Gosu::Color::BLACK, 10_000)
    Gosu.draw_rect(0, playbar_y, width, @playbar_h, Gosu::Color.new(255, 40, 40, 40), 10_001)
    Gosu.draw_rect(0, playbar_y - 1, width, 1, Gosu::Color.rgba(255, 255, 255, 30), 10_002)

    draw_controls
    draw_play_status
    draw_toast

    return nil
  end

  def needs_cursor?
    return true
  end


  # ===================== INPUT =====================


  def button_down(id)
    case id
    when Gosu::MsWheelUp
      new_scroll = @scroll_y - 40
      if new_scroll < 0
        new_scroll = 0
      end
      @scroll_y = new_scroll

    when Gosu::MsWheelDown
      list_y = @sidebar_y + HEADER_H
      list_h = height - @sidebar_y - list_y - 90
      content_h = @album_array.length * ROW_H
      max_scroll = content_h - list_h
      if max_scroll < 0
        max_scroll = 0
      end
      new_scroll = @scroll_y + 40
      if new_scroll > max_scroll
        new_scroll = max_scroll
      end
      @scroll_y = new_scroll

    when Gosu::MsLeft
      x = mouse_x
      y = mouse_y

      # Toggle playlist by clicking the square header area
      if point_in_rect?(x, y, header_rect)
          @show_playlist = true
        return nil
      end

      # Transport controls
      if handle_transport_click(x, y) == true
        return nil
      end

      # Playlist row click (play/pause)
      if @show_playlist == true
        row = get_playlist_row_clicked(x, y)
        if row != nil
          @playlist_selected_index = row
          item = @playlist[row]
          ai   = item[:album]
          ti   = item[:track]

          album = @album_array[ai]
          track = nil
          if album != nil
            track = album.tracks[ti]
          end

          if track != nil && track.location == @song
            if @song.playing?
              @song.pause
            else
              @song.play
            end
          else
            play_track(ai, ti)
          end
          return nil
        end
      end

      # Album click (works even if playlist is open)
      clicked_album = get_album_clicked(x, y)
      if clicked_album != nil
        @track_print = clicked_album
        @show_playlist = false      # leave playlist view
        if @current_album_index != @track_print
          @current_track_index = nil
        end
        return nil
      end

      # Track row click (album view only)
      if @track_print != nil && @show_playlist == false
        row = get_track_clicked(x, y, @album_array[@track_print])
        if row != nil
          play_track(@track_print, row)
        end
      end
    end

    return nil
  end
end

# Show is a method that loops through update and draw
MusicPlayerMain.new.show if __FILE__ == $0
