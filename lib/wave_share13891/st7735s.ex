defmodule WaveShare13891.ST7735S do
  @moduledoc """
  Waveshare 13891 LCD low level interface module.

  see https://files.waveshare.com/upload/e/e2/ST7735S_V1.1_20111121.pdf
  """

  defmodule Handles do
    @moduledoc false

    defstruct width: nil,
              height: nil,
              scanning_direction: nil,
              x_adjust: nil,
              y_adjust: nil,
              lcd_cs: nil,
              lcd_rst: nil,
              lcd_dc: nil,
              lcd_bl: nil,
              spi_bus: nil

    def new do
      %__MODULE__{}
    end

    def set_scanning_direction(handles, scanning_direction) do
      %{handles | scanning_direction: scanning_direction}
    end

    def set_gram_scan_way(handles, width, height, x_adjust, y_adjust) do
      %{handles | width: width, height: height, x_adjust: x_adjust, y_adjust: y_adjust}
    end

    def set_lcd_cs(handles, value) do
      %{handles | lcd_cs: value}
    end

    def set_lcd_rst(handles, value) do
      %{handles | lcd_rst: value}
    end

    def set_lcd_dc(handles, value) do
      %{handles | lcd_dc: value}
    end

    def set_lcd_bl(handles, value) do
      %{handles | lcd_bl: value}
    end

    def set_spi_bus(handles, value) do
      %{handles | spi_bus: value}
    end
  end

  import Bitwise

  alias Circuits.{GPIO, SPI}

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

  @default_bus_name "spidev0.0"
  @speed_hz 20_000_000
  @delay_us 0

  # output pins
  # @pin_out_lcd_cs 8
  @pin_out_lcd_rst 27
  @pin_out_lcd_dc 25
  @pin_out_lcd_bl 24

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

  @type pin_level() :: 0 | 1

  defguard is_pin_level(value) when value in [0, 1]

  @spec high?(integer(), integer()) :: boolean()
  defmacrop high?(value, bit) do
    quote do
      (unquote(value) &&& unquote(bit)) != 0
    end
  end

  def get_memory_data_access_control(scanning_direction) do
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

  def initialize_gpio(handles) do
    # {:ok, lcd_cs} = GPIO.open(@pin_out_lcd_cs, :output)
    {:ok, lcd_rst} = GPIO.open(@pin_out_lcd_rst, :output)
    {:ok, lcd_dc} = GPIO.open(@pin_out_lcd_dc, :output)
    {:ok, lcd_bl} = GPIO.open(@pin_out_lcd_bl, :output)

    %{handles | lcd_rst: lcd_rst, lcd_dc: lcd_dc, lcd_bl: lcd_bl}
  end

  def initialize_spi(handles) do
    {:ok, spi_bus} = SPI.open(@default_bus_name, speed_hz: @speed_hz, delay_us: @delay_us)

    %{handles | spi_bus: spi_bus}
  end

  @doc """
  see
  - https://www.waveshare.com/wiki/1.44inch_LCD_HAT#Demo
  - https://files.waveshare.com/upload/f/fa/1.44inch-LCD-HAT-Code.7z
  """
  def initialize(handles, scanning_direction) do
    handles =
      handles
      |> Handles.set_scanning_direction(scanning_direction)
      |> initialize_gpio()
      |> initialize_spi()

    set_backlight(handles, false)

    hardware_reset(handles)

    set_initialization_register(handles)

    {width, height, x_adjust, y_adjust} = set_gram_scan_way(handles, handles.scanning_direction)

    :timer.sleep(100)

    sleep_out(handles)

    :timer.sleep(120)

    turn_on_lcd_display(handles)

    Handles.set_gram_scan_way(handles, width, height, x_adjust, y_adjust)
  end

  def set_backlight(handles, condition) do
    value =
      if condition do
        1
      else
        0
      end

    set_lcd_bl(handles, value)
  end

  def set_window(handles, x_start, y_start, x_end, y_end, x_adjust, y_adjust) do
    x_parameter = <<0x00, rem(x_start, 0x100) + x_adjust, 0x00, rem(x_end, 0x100) + x_adjust>>
    y_parameter = <<0x00, rem(y_start, 0x100) + y_adjust, 0x00, rem(y_end, 0x100) + y_adjust>>

    write_register(handles, @register_caset, x_parameter)
    write_register(handles, @register_raset, y_parameter)
    select_register(handles, @register_ramwr)
  end

  def write_data(handles, data) do
    set_lcd_dc(handles, 1)

    Stream.unfold(data, fn data ->
      case String.split_at(data, 256) do
        {"", ""} -> nil
        tuple -> tuple
      end
    end)
    |> Enum.each(&transfer(handles, &1))
  end

  def hardware_reset(handles) do
    set_lcd_rst(handles, 1)
    :timer.sleep(100)

    set_lcd_rst(handles, 0)
    :timer.sleep(100)

    set_lcd_rst(handles, 1)
    :timer.sleep(100)
  end

  def set_initialization_register(handles) do
    frame_rate(handles)
    column_inversion(handles)
    power_sequence(handles)
    vcom(handles)
    gamma_sequence(handles)
    enable_test_command(handles)
    disable_ram_power_save_mode(handles)
    mode_65k(handles)
  end

  def frame_rate(handles) do
    # Set the frame frequency of the full colors normal mode.
    write_register(handles, @register_frmctr1, <<0x01, 0x2C, 0x2D>>)
    # Set the frame frequency of the Idle mode.
    write_register(handles, @register_frmctr2, <<0x01, 0x2C, 0x2D>>)
    # Set the frame frequency of the Partial mode/ full colors.
    write_register(handles, @register_frmctr3, <<0x01, 0x2C, 0x2D, 0x01, 0x2C, 0x2D>>)
  end

  def column_inversion(handles) do
    write_register(handles, @register_invctr, <<0x07>>)
  end

  def power_sequence(handles) do
    write_register(handles, @register_pwctr1, <<0xA2, 0x02, 0x84>>)
    write_register(handles, @register_pwctr2, <<0xC5>>)
    write_register(handles, @register_pwctr3, <<0x0A, 0x00>>)
    write_register(handles, @register_pwctr4, <<0x8A, 0x2A, 0xC4, 0x8A, 0xEE>>)
    write_register(handles, @register_pwctr5, <<0x8A, 0xEE>>)
  end

  def vcom(handles) do
    write_register(handles, @register_vmctr1, <<0x0E>>)
  end

  def gamma_sequence(handles) do
    write_register(
      handles,
      @register_gmctrp1,
      <<0x0F, 0x1A, 0x0F, 0x18, 0x2F, 0x28, 0x20, 0x22, 0x1F, 0x1B, 0x23, 0x37, 0x00, 0x07, 0x02, 0x10>>
    )

    write_register(
      handles,
      @register_gmctrn1,
      <<0x0F, 0x1B, 0x0F, 0x17, 0x33, 0x2C, 0x29, 0x2E, 0x30, 0x30, 0x39, 0x3F, 0x00, 0x07, 0x03, 0x10>>
    )
  end

  def enable_test_command(handles) do
    write_register(handles, 0xF0, <<0x01>>)
  end

  def disable_ram_power_save_mode(handles) do
    write_register(handles, 0xF6, <<0x00>>)
  end

  def mode_65k(handles) do
    write_register(handles, @register_colmod, <<0x05>>)
  end

  def set_gram_scan_way(handles, scanning_direction) do
    memory_data_access_control = get_memory_data_access_control(scanning_direction)

    write_register(handles, @register_madctl, <<memory_data_access_control ||| @rgb_order>>)

    if high?(memory_data_access_control, @mv) do
      {@width, @height, @y_adjust, @x_adjust}
    else
      {@height, @width, @x_adjust, @y_adjust}
    end
  end

  def sleep_out(handles) do
    select_register(handles, @register_slpout)
  end

  def turn_on_lcd_display(handles) do
    select_register(handles, @register_dispon)
  end

  def write_register(handles, register, data) do
    select_register(handles, register)
    write_data(handles, data)
  end

  def transfer(handles, data) do
    SPI.transfer(handles.spi_bus, data)
  end

  defp select_register(handles, register) do
    set_lcd_dc(handles, 0)
    transfer(handles, <<register>>)
  end

  defp set_lcd_cs(handles, value) do
    set(handles, :lcd_cs, value)
  end

  defp set_lcd_rst(handles, value) do
    set(handles, :lcd_rst, value)
  end

  defp set_lcd_dc(handles, value) do
    set(handles, :lcd_dc, value)
  end

  defp set_lcd_bl(handles, value) do
    set(handles, :lcd_bl, value)
  end

  defp set(handles, port, value) do
    case port do
      :lcd_cs -> handles.lcd_cs
      :lcd_rst -> handles.lcd_rst
      :lcd_dc -> handles.lcd_dc
      :lcd_bl -> handles.lcd_bl
    end
    |> GPIO.write(value)
  end
end
