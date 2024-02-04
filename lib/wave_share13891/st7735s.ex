defmodule WaveShare13891.ST7735S do
  @moduledoc """
  Waveshare 13891 LCD low level interface module.

  see https://files.waveshare.com/upload/e/e2/ST7735S_V1.1_20111121.pdf
  """

  defmodule Handles do
    @moduledoc false

    defstruct width: nil,
              height: nil,
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

  # MY : Row Address Order bit (0: top to bottom, 1: bottom to top)
  @bottom_to_top 0b10000000

  # MX : Column Address Order bit (0: left to right, 1: right to left)
  @right_to_left 0b01000000

  # MV : Row/Column Exchange bit (0: normal, 1: row/column exchange)
  @exchange_row_column 0b00100000

  # ML : Vertical Refresh Order bit (0: LCD vertical refresh Top to Bottom, 1: LCD vertical refresh Bottom to Top)
  # @ml 0b00010000

  # RGB-BGR Order bit (0: RGB color filter panel, 1: BGR color filter panel)
  @rgb_order 0b00001000

  @height 128
  @width 128
  @x_adjust 2
  @y_adjust 1

  # MADCTL : Memory Data Access Control
  @register_madctl 0x36

  # FRMCTR1 : Frame Rate Control (In normal mode/ Full colors)
  @register_frmctr1 0xB1

  # FRMCTR2 : Frame Rate Control (In Idle mode/ 8-colors)
  @register_frmctr2 0xB2

  # FRMCTR3 : Frame Rate Control (In Partial mode/ full colors)
  @register_frmctr3 0xB3

  # INVCTR : Display Inversion Control
  @register_invctr 0xB4

  # PWCTR1 : Power Control 1
  @register_pwctr1 0xC0

  # PWCTR2 : Power Control 2
  @register_pwctr2 0xC1

  # PWCTR3 : Power Control 3 (in Normal mode/ Full colors)
  @register_pwctr3 0xC2

  # PWCTR4 : Power Control 4 (in Idle mode/ 8-colors)
  @register_pwctr4 0xC3

  # PWCTR5 : Power Control 5 (in Partial mode/ full-colors)
  @register_pwctr5 0xC4

  # VMCTR1 : VCOM Control 1
  @register_vmctr1 0xC5

  # GMCTRP1 : Gamma (‘+’polarity) Correction Characteristics Setting
  @register_gmctrp1 0xE0

  # GMCTRN1 : Gamma ‘-’polarity Correction Characteristics Setting
  @register_gmctrn1 0xE1

  # COLMOD : Interface Pixel Format
  @register_colmod 0x3A

  # SLPOUT : Sleep Out
  @register_slpout 0x11

  # DISPON : Display On
  @register_dispon 0x29

  # CASET : Column Address Set
  @register_caset 0x2A

  # RASET : Row Address Set
  @register_raset 0x2B

  # RAMWR : Memory Write
  @register_ramwr 0x2C

  @default_bus_name "spidev0.0"
  @speed_hz 20_000_000
  @delay_us 0

  # GPIO
  # @gpio_outlcd_cs 8
  @gpio_outlcd_rst 27
  @gpio_outlcd_dc 25
  @gpio_outlcd_bl 24

  @type scanning_direction() ::
          :l2r_u2d
          | :l2r_d2u
          | :r2l_u2d
          | :r2l_d2u
          | :u2d_l2r
          | :u2d_r2l
          | :d2u_l2r
          | :d2u_r2l

  @opaque handles() :: %Handles{
            width: non_neg_integer(),
            height: nil | non_neg_integer(),
            x_adjust: nil | non_neg_integer(),
            y_adjust: nil | non_neg_integer(),
            lcd_cs: nil | Circuits.GPIO.Handle.t(),
            lcd_rst: nil | Circuits.GPIO.Handle.t(),
            lcd_dc: nil | Circuits.GPIO.Handle.t(),
            lcd_bl: nil | Circuits.GPIO.Handle.t(),
            spi_bus: nil | Circuits.SPI.Bus.t()
          }

  @spec is_scanning_direction(term()) :: scanning_direction()
  defguardp is_scanning_direction(term)
            when term in [:l2r_u2d, :l2r_d2u, :r2l_u2d, :r2l_d2u, :u2d_l2r, :u2d_r2l, :d2u_l2r, :d2u_r2l]

  @spec high?(integer(), integer()) :: boolean()
  defguardp high?(value, bit) when is_integer(value) and is_integer(bit) and (value &&& bit) != 0

  @doc """
  Initializes ST7735S.

  see:
  - https://www.waveshare.com/wiki/1.44inch_LCD_HAT#Demo
  - https://files.waveshare.com/upload/f/fa/1.44inch-LCD-HAT-Code.7z
  """
  @spec initialize(scanning_direction()) :: handles()
  def initialize(scanning_direction) when is_scanning_direction(scanning_direction) do
    memory_data_access_control = get_memory_data_access_control(scanning_direction)

    handles = initialize_device()
    set_backlight(handles, false)
    hardware_reset(handles)
    initialize_register(handles)
    set_gram_scan_way(handles, memory_data_access_control)
    :timer.sleep(100)
    sleep_out(handles)
    :timer.sleep(120)
    turn_on_lcd_display(handles)

    if high?(memory_data_access_control, @exchange_row_column) do
      Handles.set_gram_scan_way(handles, @width, @height, @y_adjust, @x_adjust)
    else
      Handles.set_gram_scan_way(handles, @height, @width, @x_adjust, @y_adjust)
    end
  end

  @doc """
  Turns on/off LCD backlight.
  """
  @spec set_backlight(handles(), boolean()) :: :ok
  def set_backlight(handles, true) when is_struct(handles, Handles), do: set(handles.lcd_bl, 1)
  def set_backlight(handles, false) when is_struct(handles, Handles), do: set(handles.lcd_bl, 0)

  @doc """
  Draws image.
  """
  @spec draw(handles(), binary(), WaveShare13891.LCD.rect()) :: :ok
  def draw(handles, data, %{x: x, y: y, width: width, height: height} = _rect)
      when is_struct(handles, Handles) and is_binary(data) do
    set_window(handles, x, y, x + width - 1, y + height - 1)
    write_data(handles, data)
  end

  defp set_window(handles, x_start, y_start, x_end, y_end) do
    x_parameter = <<0x00, rem(x_start, 0x100) + handles.x_adjust, 0x00, rem(x_end, 0x100) + handles.x_adjust>>
    y_parameter = <<0x00, rem(y_start, 0x100) + handles.y_adjust, 0x00, rem(y_end, 0x100) + handles.y_adjust>>

    write_register(handles, @register_caset, x_parameter)
    write_register(handles, @register_raset, y_parameter)
    select_register(handles, @register_ramwr)
  end

  defp write_register(handles, register, data) do
    select_register(handles, register)
    write_data(handles, data)
  end

  defp write_data(handles, data) do
    set(handles.lcd_dc, 1)

    Stream.unfold(data, fn data ->
      case String.split_at(data, 256) do
        {"", ""} -> nil
        tuple -> tuple
      end
    end)
    |> Enum.each(&transfer(handles, &1))
  end

  defp get_memory_data_access_control(scanning_direction) do
    case scanning_direction do
      :l2r_u2d -> 0
      :l2r_d2u -> @bottom_to_top
      :r2l_u2d -> @right_to_left
      :r2l_d2u -> @right_to_left ||| @bottom_to_top
      :u2d_l2r -> @exchange_row_column
      :u2d_r2l -> @exchange_row_column ||| @right_to_left
      :d2u_l2r -> @exchange_row_column ||| @bottom_to_top
      :d2u_r2l -> @exchange_row_column ||| @right_to_left ||| @bottom_to_top
    end
  end

  defp initialize_device do
    # {:ok, lcd_cs} = GPIO.open(@gpio_outlcd_cs, :output)
    {:ok, lcd_rst} = GPIO.open(@gpio_outlcd_rst, :output)
    {:ok, lcd_dc} = GPIO.open(@gpio_outlcd_dc, :output)
    {:ok, lcd_bl} = GPIO.open(@gpio_outlcd_bl, :output)
    {:ok, spi_bus} = SPI.open(@default_bus_name, speed_hz: @speed_hz, delay_us: @delay_us)

    Handles.new()
    |> Handles.set_lcd_rst(lcd_rst)
    |> Handles.set_lcd_dc(lcd_dc)
    |> Handles.set_lcd_bl(lcd_bl)
    |> Handles.set_spi_bus(spi_bus)
  end

  defp hardware_reset(handles) do
    set(handles.lcd_rst, 1)
    :timer.sleep(100)

    set(handles.lcd_rst, 0)
    :timer.sleep(100)

    set(handles.lcd_rst, 1)
    :timer.sleep(100)
  end

  defp initialize_register(handles) do
    frame_rate(handles)
    column_inversion(handles)
    power_sequence(handles)
    vcom(handles)
    gamma_sequence(handles)
    enable_test_command(handles)
    disable_ram_power_save_mode(handles)
    mode_65k(handles)
  end

  defp frame_rate(handles) do
    # Set the frame frequency of the full colors normal mode.
    write_register(handles, @register_frmctr1, <<0x01, 0x2C, 0x2D>>)
    # Set the frame frequency of the Idle mode.
    write_register(handles, @register_frmctr2, <<0x01, 0x2C, 0x2D>>)
    # Set the frame frequency of the Partial mode/ full colors.
    write_register(handles, @register_frmctr3, <<0x01, 0x2C, 0x2D, 0x01, 0x2C, 0x2D>>)
  end

  defp column_inversion(handles) do
    write_register(handles, @register_invctr, <<0x07>>)
  end

  defp power_sequence(handles) do
    write_register(handles, @register_pwctr1, <<0xA2, 0x02, 0x84>>)
    write_register(handles, @register_pwctr2, <<0xC5>>)
    write_register(handles, @register_pwctr3, <<0x0A, 0x00>>)
    write_register(handles, @register_pwctr4, <<0x8A, 0x2A>>)
    write_register(handles, @register_pwctr5, <<0x8A, 0xEE>>)
  end

  defp vcom(handles) do
    write_register(handles, @register_vmctr1, <<0x0E>>)
  end

  defp gamma_sequence(handles) do
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

  defp enable_test_command(handles) do
    write_register(handles, 0xF0, <<0x01>>)
  end

  defp disable_ram_power_save_mode(handles) do
    write_register(handles, 0xF6, <<0x00>>)
  end

  defp mode_65k(handles) do
    write_register(handles, @register_colmod, <<0x05>>)
  end

  defp set_gram_scan_way(handles, memory_data_access_control) do
    write_register(handles, @register_madctl, <<memory_data_access_control ||| @rgb_order>>)
  end

  defp sleep_out(handles) do
    select_register(handles, @register_slpout)
  end

  defp turn_on_lcd_display(handles) do
    select_register(handles, @register_dispon)
  end

  defp select_register(handles, register) do
    set(handles.lcd_dc, 0)
    transfer(handles, <<register>>)
  end

  defp set(handle, value) do
    GPIO.write(handle, value)
  end

  defp transfer(handles, data) do
    SPI.transfer(handles.spi_bus, data)
  end
end
