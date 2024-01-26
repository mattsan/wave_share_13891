defmodule WaveShare13891.ST7735S do
  @moduledoc """
  Waveshare 13891 LCD low level interface module.

  see https://files.waveshare.com/upload/e/e2/ST7735S_V1.1_20111121.pdf
  """

  alias WaveShare13891.{GPIO, SPI}

  import Bitwise

  # Row Address Order bit (0: top to bottom, 1: bottom to top)
  @my 0x80

  # Column Address Order bit (0: left to right, 1: right to left)
  @mx 0x40

  # Row/Column Exchange bit (0: normal, 1: row/column exchange)
  @mv 0x20

  # Vertical Refresh Order bit (0: LCD vertical refresh Top to Bottom, 1: LCD vertical refresh Bottom to Top)
  # @ml 0x10

  # RGB-BGR Order bit (0: RGB color filter panel, 1: BGR color filter panel)
  @rgb_order 0x08

  @height 128
  @width 128
  @x_adjust 2
  @y_adjust 1

  # MADCTL (36h): Memory Data Access Control
  @register_madctl 0x36

  # FRMCTR1 (B1h): Frame Rate Control (In normal mode/ Full colors)
  @register_frmctr1 0xB1

  # FRMCTR2 (B2h): Frame Rate Control (In Idle mode/ 8-colors)
  @register_frmctr2 0xB2

  # FRMCTR3 (B3h): Frame Rate Control (In Partial mode/ full colors)
  @register_frmctr3 0xB3

  # INVCTR (B4h): Display Inversion Control
  @register_invctr 0xB4

  # PWCTR1 (C0h): Power Control 1
  @register_pwctr1 0xC0

  # PWCTR2 (C1h): Power Control 2
  @register_pwctr2 0xC1

  # PWCTR3 (C2h): Power Control 3 (in Normal mode/ Full colors)
  @register_pwctr3 0xC2

  # PWCTR4 (C3h): Power Control 4 (in Idle mode/ 8-colors)
  @register_pwctr4 0xC3

  # PWCTR5 (C4h): Power Control 5 (in Partial mode/ full-colors)
  @register_pwctr5 0xC4

  # VMCTR1 (C5h): VCOM Control 1
  @register_vmctr1 0xC5

  # GMCTRP1 (E0h): Gamma (‘+’polarity) Correction Characteristics Setting
  @register_gmctrp1 0xE0

  # GMCTRN1 (E1h): Gamma ‘-’polarity Correction Characteristics Setting
  @register_gmctrn1 0xE1

  # COLMOD (3Ah): Interface Pixel Format
  @register_colmod 0x3A

  # SLPOUT (11h): Sleep Out
  @register_slpout 0x11

  # DISPON (29h): Display On
  @register_dispon 0x29

  # CASET (2Ah): Column Address Set
  @register_caset 0x2A

  # RASET (2Bh): Row Address Set
  @register_raset 0x2B

  # RAMWR (2Ch): Memory Write
  @register_ramwr 0x2C

  @type scanning_direction() ::
          :l2r_u2d
          | :l2r_d2u
          | :r2l_u2d
          | :r2l_d2u
          | :u2d_l2r
          | :u2d_r2l
          | :d2u_l2r
          | :d2u_r2l

  @type device_spec() :: {
          height :: pos_integer(),
          width :: pos_integer(),
          x_adjust :: non_neg_integer(),
          y_adjust :: non_neg_integer()
        }

  @spec initialize(scanning_direction()) :: device_spec()
  def initialize(scanning_direction) do
    set_backlight(false)

    hardware_reset()

    st7735r_frame_rate()
    st7735r_power_sequence()
    st7735r_gamma_sequence()

    info = set_gram_scan_way(scanning_direction)

    :timer.sleep(200)

    sleep_out()

    :timer.sleep(120)

    turn_on_lcd_display()

    info
  end

  def set_window(x_start, y_start, x_end, y_end, x_adjust, y_adjust) do
    x_parameter = <<0x00, rem(x_start, 0x100) + x_adjust, 0x00, rem(x_end, 0x100) + x_adjust>>
    y_parameter = <<0x00, rem(y_start, 0x100) + y_adjust, 0x00, rem(y_end, 0x100) + y_adjust>>

    write_register(@register_caset, x_parameter)
    write_register(@register_raset, y_parameter)
    select_register(@register_ramwr)
  end

  @spec set_backlight(boolean()) :: :ok
  def set_backlight(condition) when is_boolean(condition) do
    value =
      if condition do
        1
      else
        0
      end

    GPIO.set_lcd_bl(value)
  end

  @spec hardware_reset :: :ok
  def hardware_reset do
    GPIO.set_lcd_rst(1)
    :timer.sleep(100)

    GPIO.set_lcd_rst(0)
    :timer.sleep(100)

    GPIO.set_lcd_rst(1)
    :timer.sleep(100)
  end

  def st7735r_frame_rate do
    # Set the frame frequency of the full colors normal mode.
    write_register(@register_frmctr1, <<0x01, 0x2C, 0x2D>>)

    # Set the frame frequency of the Idle mode.
    write_register(@register_frmctr2, <<0x01, 0x2C, 0x2D>>)

    # Set the frame frequency of the Partial mode/ full colors.
    write_register(@register_frmctr3, <<0x01, 0x2C, 0x2D, 0x01, 0x2C, 0x2D>>)

    write_register(@register_invctr, <<0x07>>)
  end

  def st7735r_power_sequence do
    write_register(@register_pwctr1, <<0xA2, 0x02, 0x84>>)
    write_register(@register_pwctr2, <<0xC5>>)
    write_register(@register_pwctr3, <<0x0A, 0x00>>)
    write_register(@register_pwctr4, <<0x8A, 0x2A, 0xC4, 0x8A, 0xEE>>)
    write_register(@register_pwctr5, <<0x8A, 0xEE>>)
    write_register(@register_vmctr1, <<0x0E>>)
  end

  def st7735r_gamma_sequence do
    write_register(
      @register_gmctrp1,
      <<0x0F, 0x1A, 0x0F, 0x18, 0x2F, 0x28, 0x20, 0x22, 0x1F, 0x1B, 0x23, 0x37, 0x00, 0x07, 0x02, 0x10>>
    )

    write_register(
      @register_gmctrn1,
      <<0x0F, 0x1B, 0x0F, 0x17, 0x33, 0x2C, 0x29, 0x2E, 0x30, 0x30, 0x39, 0x3F, 0x00, 0x07, 0x03, 0x10>>
    )

    # Enable test command
    write_register(0xF0, <<0x01>>)

    # Disable ram power save mode
    write_register(0xF6, <<0x00>>)

    # 65k mode
    write_register(@register_colmod, <<0x05>>)
  end

  defp get_memory_data_access_control(scanning_direction) do
    case scanning_direction do
      :l2r_u2d -> 0
      :l2r_d2u -> @my
      :r2l_u2d -> @mx
      :r2l_d2u -> @mx ||| @my
      :u2d_l2r -> @mv
      :u2d_r2l -> @mv ||| @mx
      :d2u_l2r -> @mv ||| @my
      :d2u_r2l -> @mv ||| @mx ||| @my
    end
  end

  @spec high?(integer(), integer()) :: boolean()
  defmacrop high?(value, bit) do
    quote do
      (unquote(value) &&& unquote(bit)) != 0
    end
  end

  def set_gram_scan_way(scanning_direction) do
    memory_data_access_control = get_memory_data_access_control(scanning_direction)

    write_register(@register_madctl, <<memory_data_access_control ||| @rgb_order>>)

    if high?(memory_data_access_control, @mv) do
      {@width, @height, @y_adjust, @x_adjust}
    else
      {@height, @width, @x_adjust, @y_adjust}
    end
  end

  def sleep_out do
    select_register(@register_slpout)
  end

  def turn_on_lcd_display do
    select_register(@register_dispon)
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

    Stream.unfold(data, fn data ->
      case String.split_at(data, 4096) do
        {"", ""} -> nil
        tuple -> tuple
      end
    end)
    |> Enum.each(&SPI.transfer/1)
  end
end
