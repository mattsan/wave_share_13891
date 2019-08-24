defmodule WaveShare13891.LCD.Device do
  alias WaveShare13891.{GPIO, SPI}

  require Bitwise
  import Bitwise

  @my 0x80
  @mx 0x40
  @mv 0x20
  @ml 0x10
  @rgb_order 0x08

  @height 128
  @width 128
  @lcd_x 2
  @lcd_y 1

  def initialize(scan_dir) do
    set_backlight(:on)
    hardware_reset()

    st7735r_frame_rate()
    st7735r_power_sequence()
    st7735r_gamma_sequence()

    info = set_gram_scan_way(scan_dir)

    :timer.sleep(200)

    sleep_out()

    :timer.sleep(120)

    turn_on_lcd_display()

    info
  end

  def set_backlight(condition) when condition in [:on, :off] do
    value =
      case condition do
        :on -> 1
        :off -> 0
      end

    GPIO.set_lcd_bl(value)
  end

  def hardware_reset do
    GPIO.set_lcd_rst(1)
    :timer.sleep(100)
    GPIO.set_lcd_rst(0)
    :timer.sleep(100)
    GPIO.set_lcd_rst(1)
    :timer.sleep(100)
  end

  def st7735r_frame_rate do
    write_register(0xb1, <<0x01, 0x2c, 0x2d>>)
    write_register(0xb2, <<0x01, 0x2c, 0x2d>>)
    write_register(0xb3, <<0x01, 0x2c, 0x2d, 0x01, 0x2c, 0x2d>>)

    # Column inversion
    write_register(0xb4, <<0x07>>)
  end

  def st7735r_power_sequence do
    write_register(0xc0, <<0xa2, 0x02, 0x84>>)
    write_register(0xc1, <<0xc5>>)
    write_register(0xc2, <<0x0a, 0x00>>)
    write_register(0xc3, <<0x8a, 0x2a, 0xc4, 0x8a, 0xee>>)
    write_register(0xc4, <<0x8a, 0xee>>)

    # vcom
    write_register(0xc5, <<0x0e>>)
  end

  def st7735r_gamma_sequence do
    write_register(0xe0, <<0x0f, 0x1a, 0x0f, 0x18, 0x2f, 0x28, 0x20, 0x22, 0x1f, 0x1b, 0x23, 0x37, 0x00, 0x07, 0x02, 0x10>>)
    write_register(0xe1, <<0x0f, 0x1b, 0x0f, 0x17, 0x33, 0x2c, 0x29, 0x2e, 0x30, 0x30, 0x39, 0x3f, 0x00, 0x07, 0x03, 0x10>>)

    # Enable test command
    write_register(0xf0, <<0x01>>)

    # Disable ram power save mode
    write_register(0xf6, <<0x00>>)

    # 65k mode
    write_register(0x3a, <<0x05>>)
  end

  def set_gram_scan_way(scan_dir) do
    memory_access_reg =
      case scan_dir do
        :l2r_u2d -> 0
        :l2r_d2u -> @my
        :r2l_u2d -> @mx
        :r2l_d2u -> @mx ||| @my
        :u2d_l2r -> @mv
        :u2d_r2l -> @mv ||| @mx
        :d2u_l2r -> @mv ||| @my
        :d2u_r2l -> @mv ||| @mx ||| @my
      end

    write_register(0x36, <<memory_access_reg ||| @rgb_order>>)

    case memory_access_reg &&& @mv do
      0 -> {@height, @width, @lcd_x, @lcd_y}
      _ -> {@width, @height, @lcd_y, @lcd_x}
    end
  end

  def sleep_out do
    select_register(0x11)
  end

  def turn_on_lcd_display do
    select_register(0x29)
  end

  def write_register(register, data) do
    select_register(register)
    write_data(data)
  end

  def select_register(register) do
    GPIO.set_lcd_dc(0)
    SPI.transfer(<<register>>)
  end

  def write_data(data) do
    GPIO.set_lcd_dc(1)
    SPI.transfer(data)
  end
end
