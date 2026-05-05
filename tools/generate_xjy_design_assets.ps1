Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Out = Join-Path $Root 'docs/final-design'
$Assets = Join-Path $Out 'assets'
New-Item -ItemType Directory -Force -Path $Out, $Assets | Out-Null

function Color($hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
function Brush($hex) { New-Object System.Drawing.SolidBrush (Color $hex) }
function PenC($hex, $w = 1) { New-Object System.Drawing.Pen (Color $hex), $w }
function FontC($size, $bold = $false) {
  $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
  New-Object System.Drawing.Font('Microsoft YaHei UI', $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
}
function Canvas($w, $h, $bg = $null) {
  $bmp = New-Object System.Drawing.Bitmap -ArgumentList $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
  if ($bg) { $g.Clear((Color $bg)) } else { $g.Clear([System.Drawing.Color]::Transparent) }
  @($bmp, $g)
}
function PathRR($x, $y, $w, $h, $r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  if ($r -le 0) {
    $p.AddRectangle((New-Object System.Drawing.RectangleF $x, $y, $w, $h))
    return $p
  }
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  $p
}
function FillRR($g, $x, $y, $w, $h, $r, $hex) {
  $path = PathRR $x $y $w $h $r
  $brush = Brush $hex
  $g.FillPath($brush, $path)
  $brush.Dispose(); $path.Dispose()
}
function StrokeRR($g, $x, $y, $w, $h, $r, $hex, $sw = 1) {
  $path = PathRR $x $y $w $h $r
  $pen = PenC $hex $sw
  $g.DrawPath($pen, $path)
  $pen.Dispose(); $path.Dispose()
}
function FillGrad($g, $x, $y, $w, $h, $r, $c1, $c2, $angle = 90) {
  $path = PathRR $x $y $w $h $r
  $rect = New-Object System.Drawing.RectangleF $x, $y, $w, $h
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (Color $c1), (Color $c2), $angle
  $g.FillPath($brush, $path)
  $brush.Dispose(); $path.Dispose()
}
function Text($g, $text, $x, $y, $size, $color, $bold = $false, $w = 0, $h = 0, $align = 'Near') {
  $font = FontC $size $bold
  $brush = Brush $color
  if ($w -gt 0) {
    $fmt = New-Object System.Drawing.StringFormat
    if ($align -eq 'Center') { $fmt.Alignment = [System.Drawing.StringAlignment]::Center }
    if ($align -eq 'Far') { $fmt.Alignment = [System.Drawing.StringAlignment]::Far }
    $rect = New-Object System.Drawing.RectangleF $x, $y, $w, $h
    $g.DrawString($text, $font, $brush, $rect, $fmt)
    $fmt.Dispose()
  } else {
    $g.DrawString($text, $font, $brush, $x, $y)
  }
  $font.Dispose(); $brush.Dispose()
}
function SavePng($bmp, $g, $path) {
  $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}
function Goldfish($g, $x, $y, $s = 1) {
  $gold = Brush '#FFB84D'; $light = Brush '#FFD98A'; $dark = Brush '#1F3440'
  $g.FillEllipse($gold, $x, $y + 18 * $s, 62 * $s, 40 * $s)
  $tail = [System.Drawing.PointF[]]@(
    (New-Object System.Drawing.PointF ($x + 58 * $s), ($y + 38 * $s)),
    (New-Object System.Drawing.PointF ($x + 94 * $s), ($y + 13 * $s)),
    (New-Object System.Drawing.PointF ($x + 94 * $s), ($y + 63 * $s))
  )
  $g.FillPolygon($light, $tail)
  $g.FillEllipse($dark, $x + 22 * $s, $y + 28 * $s, 7 * $s, 7 * $s)
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(180, 255, 255, 255)), (4 * $s)
  $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
  $g.DrawArc($pen, $x + 10 * $s, $y + 31 * $s, 44 * $s, 22 * $s, 20, 135)
  $gold.Dispose(); $light.Dispose(); $dark.Dispose(); $pen.Dispose()
}
function IconLine($g, $kind, $x, $y, $s, $color) {
  $pen = PenC $color (4 * $s)
  $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
  switch ($kind) {
    'list' {
      for ($i = 0; $i -lt 3; $i++) {
        $yy = $y + (6 + $i * 11) * $s
        $g.FillEllipse((Brush $color), $x, $yy - 2 * $s, 5 * $s, 5 * $s)
        $g.DrawLine($pen, $x + 12 * $s, $yy, $x + 38 * $s, $yy)
      }
    }
    'calendar' {
      StrokeRR $g ($x + 2 * $s) ($y + 4 * $s) (38 * $s) (34 * $s) (4 * $s) $color (4 * $s)
      $g.DrawLine($pen, $x + 2 * $s, $y + 15 * $s, $x + 40 * $s, $y + 15 * $s)
      $g.FillRectangle((Brush $color), $x + 14 * $s, $y + 23 * $s, 9 * $s, 9 * $s)
    }
    'plus' {
      $g.DrawLine($pen, $x + 20 * $s, $y + 8 * $s, $x + 20 * $s, $y + 32 * $s)
      $g.DrawLine($pen, $x + 8 * $s, $y + 20 * $s, $x + 32 * $s, $y + 20 * $s)
    }
    'stats' {
      $g.FillPie((Brush $color), $x + 2 * $s, $y + 2 * $s, 38 * $s, 38 * $s, 90, 180)
      $g.FillPie((Brush '#9AAAB5'), $x + 2 * $s, $y + 2 * $s, 38 * $s, 38 * $s, 270, 90)
    }
    'gear' {
      $g.DrawEllipse($pen, $x + 8 * $s, $y + 8 * $s, 24 * $s, 24 * $s)
      $g.DrawLine($pen, $x + 20 * $s, $y + 2 * $s, $x + 20 * $s, $y + 8 * $s)
      $g.DrawLine($pen, $x + 20 * $s, $y + 32 * $s, $x + 20 * $s, $y + 38 * $s)
      $g.DrawLine($pen, $x + 2 * $s, $y + 20 * $s, $x + 8 * $s, $y + 20 * $s)
      $g.DrawLine($pen, $x + 32 * $s, $y + 20 * $s, $x + 38 * $s, $y + 20 * $s)
    }
    default {
      Text $g $kind $x $y (26 * $s) $color $true (44 * $s) (44 * $s) 'Center'
    }
  }
  $pen.Dispose()
}
function CategoryIcon($name, $label, $bg) {
  $pair = Canvas 160 160
  $bmp = $pair[0]; $g = $pair[1]
  $brush = Brush $bg
  $g.FillEllipse($brush, 16, 16, 128, 128)
  $brush.Dispose()
  Text $g $label 16 52 44 '#FFFFFF' $true 128 60 'Center'
  SavePng $bmp $g (Join-Path $Assets "$name.png")
}
function TabIcon($name, $kind, $color, $circle = $false) {
  $pair = Canvas 160 160
  $bmp = $pair[0]; $g = $pair[1]
  if ($circle) {
    $brush = Brush '#FFB84D'
    $g.FillEllipse($brush, 16, 16, 128, 128)
    $brush.Dispose()
    IconLine $g $kind 54 54 1.3 '#FFFFFF'
  } else {
    IconLine $g $kind 52 52 1.35 $color
  }
  SavePng $bmp $g (Join-Path $Assets "$name.png")
}
function StatusBar($g) {
  Text $g '11:03' 34 48 36 '#1F3440'
  Text $g '5A  78%' 850 50 24 '#1F3440' $true 180 30 'Far'
}
function BottomTab($g, $active) {
  FillRR $g 0 2068 1080 272 0 '#FFFFFF'
  $tabs = @(
    @('账单', 'list'), @('日历', 'calendar'), @('记账', 'plus'), @('统计', 'stats'), @('设置', 'gear')
  )
  for ($i = 0; $i -lt 5; $i++) {
    $x = 100 + $i * 220
    if ($i -eq 2) {
      $brush = Brush '#FFB84D'
      $g.FillEllipse($brush, $x - 54, 2022, 132, 132)
      $brush.Dispose()
      IconLine $g 'plus' ($x - 8) 2064 1.2 '#FFFFFF'
      Text $g '记账' ($x - 75) 2164 28 $(if ($active -eq '记账') { '#1F3440' } else { '#7A8B99' }) $true 150 38 'Center'
    } else {
      $color = if ($active -eq $tabs[$i][0]) { '#1F3440' } else { '#9AAAB5' }
      IconLine $g $tabs[$i][1] ($x - 22) 2070 1.25 $color
      Text $g $tabs[$i][0] ($x - 75) 2164 28 $color $false 150 38 'Center'
    }
  }
  FillRR $g 370 2255 340 12 6 '#A6A6A6'
}
function MonthSelector($g, $y) {
  FillRR $g 54 $y 972 120 60 '#FFFFFF'
  StrokeRR $g 54 $y 972 120 60 '#1F3440' 5
  Text $g '‹' 115 ($y + 22) 56 '#1F3440'
  Text $g '2026年4月' 0 ($y + 28) 46 '#1F3440' $true 1080 62 'Center'
  Text $g '›' 930 ($y + 22) 56 '#D7DEE5'
}
function Chip($g, $x, $y, $w, $text, $selected = $false) {
  FillRR $g $x $y $w 74 37 $(if ($selected) { '#FFD36B' } else { '#FFFFFF' })
  StrokeRR $g $x $y $w 74 37 '#E7F0EF' 1
  Text $g $text $x ($y + 18) 30 $(if ($selected) { '#FFFFFF' } else { '#9AAAB5' }) $true $w 40 'Center'
}
function SummaryCard($g, $x, $y, $w, $h, $amount, $balance) {
  FillGrad $g $x $y $w $h 46 '#203850' '#21A7A8' 25
  Goldfish $g ($x + $w - 190) ($y + 38) 1.35
  Text $g '本月支出' ($x + 70) ($y + 58) 32 '#C8D8DE'
  Text $g $amount ($x + 70) ($y + 108) 78 '#FFFFFF' $true
  Text $g '收入' ($x + 70) ($y + $h * .68) 31 '#C8D8DE'
  Text $g '+¥0.00' ($x + 70) ($y + $h * .79) 36 '#FFFFFF' $true
  Text $g '结余' ($x + $w * .62) ($y + $h * .68) 31 '#C8D8DE'
  Text $g $balance ($x + $w * .62) ($y + $h * .79) 36 '#EF5B73' $true
}
function BillRow($g, $x, $y) {
  FillRR $g $x $y 970 132 30 '#FFFFFF'
  $brush = Brush '#FF6B45'
  $g.FillEllipse($brush, $x + 35, $y + 30, 72, 72)
  $brush.Dispose()
  Text $g '餐' ($x + 35) ($y + 43) 34 '#FFFFFF' $true 72 48 'Center'
  Text $g '餐饮' ($x + 140) ($y + 30) 35 '#1F3440' $true
  Text $g '猪脚饭' ($x + 140) ($y + 77) 28 '#7A8B99'
  Text $g '-¥25.00' ($x + 700) ($y + 43) 42 '#EF5B73' $true 230 56 'Far'
}
function NewPage($name) {
  $pair = Canvas 1080 2340 '#F7FBFA'
  $bmp = $pair[0]; $g = $pair[1]
  StatusBar $g
  @($bmp, $g)
}

# 拆分资源
$pair = Canvas 1024 1024
$bmp = $pair[0]; $g = $pair[1]
FillGrad $g 0 0 1024 1024 220 '#21A7A8' '#62D5C8' 45
Goldfish $g 245 330 6.2
SavePng $bmp $g (Join-Path $Assets 'xjy_app_icon.png')

$pair = Canvas 512 512
$bmp = $pair[0]; $g = $pair[1]
Goldfish $g 105 150 3.1
SavePng $bmp $g (Join-Path $Assets 'xjy_goldfish_mark.png')

$pair = Canvas 1080 420 '#F7FBFA'
$bmp = $pair[0]; $g = $pair[1]
FillGrad $g 0 0 1080 420 0 '#21A7A8' '#64D7CA' 0
Goldfish $g 760 80 2.2
SavePng $bmp $g (Join-Path $Assets 'xjy_header_bg.png')

$pair = Canvas 1080 520
$bmp = $pair[0]; $g = $pair[1]
FillGrad $g 0 0 1080 520 56 '#203850' '#21A7A8' 35
Goldfish $g 790 70 1.55
SavePng $bmp $g (Join-Path $Assets 'xjy_summary_card_bg.png')

$pair = Canvas 512 512
$bmp = $pair[0]; $g = $pair[1]
IconLine $g 'list' 190 150 3 '#D7DEE5'
Goldfish $g 190 250 1.1
Text $g '还没有记录' 0 360 30 '#A9B4BE' $true 512 50 'Center'
SavePng $bmp $g (Join-Path $Assets 'xjy_empty_bill.png')

TabIcon 'tab_bill_inactive' 'list' '#9AAAB5'
TabIcon 'tab_bill_active' 'list' '#1F3440'
TabIcon 'tab_calendar_inactive' 'calendar' '#9AAAB5'
TabIcon 'tab_calendar_active' 'calendar' '#1F3440'
TabIcon 'tab_add' 'plus' '#FFFFFF' $true
TabIcon 'tab_stats_inactive' 'stats' '#9AAAB5'
TabIcon 'tab_stats_active' 'stats' '#1F3440'
TabIcon 'tab_settings_inactive' 'gear' '#9AAAB5'
TabIcon 'tab_settings_active' 'gear' '#1F3440'
CategoryIcon 'cat_food' '餐' '#FF6B45'
CategoryIcon 'cat_transport' '交' '#39A8F2'
CategoryIcon 'cat_shopping' '购' '#EF5B73'
CategoryIcon 'cat_entertainment' '娱' '#A845C5'
CategoryIcon 'cat_housing' '住' '#21A7A8'
CategoryIcon 'cat_medical' '医' '#F04E4E'
CategoryIcon 'cat_education' '学' '#5666C9'
CategoryIcon 'cat_other' '···' '#78909C'

# 首页
$pair = NewPage 'home'
$bmp = $pair[0]; $g = $pair[1]
FillGrad $g 0 0 1080 250 0 '#FFDE7A' '#FFD36B' 90
Text $g '搜索' 65 135 31 '#FFFFFF' $true
Text $g '小金鱼记账' 0 124 46 '#1F3440' $true 1080 64 'Center'
MonthSelector $g 290
SummaryCard $g 48 505 984 510 '¥25.00' '¥25.00'
Chip $g 260 1065 170 '全部' $true
Chip $g 455 1065 170 '收入'
Chip $g 650 1065 170 '支出'
Text $g '4月15日 星期三' 58 1210 34 '#7A8B99' $true
Text $g '-25.00' 832 1210 34 '#EF5B73' $true
BillRow $g 48 1285
BottomTab $g '账单'
SavePng $bmp $g (Join-Path $Out 'page_home.png')

# 记账页
$pair = NewPage 'add'
$bmp = $pair[0]; $g = $pair[1]
FillGrad $g 0 0 1080 720 0 '#21A7A8' '#FFD36B' 90
FillRR $g 285 180 250 90 45 '#1F3440'
Text $g '支出' 285 198 40 '#FFFFFF' $true 250 52 'Center'
Text $g '收入' 545 198 40 '#1F3440' $false 250 52 'Center'
Text $g '金额' 70 340 34 '#1F3440'
Text $g '¥' 70 410 84 '#1F3440' $true
Text $g '0.00' 155 436 42 '#7A8B99'
FillRR $g 360 610 360 70 35 '#FFD36B'
Text $g '2026-04-29' 360 624 34 '#1F3440' $true 360 42 'Center'
FillRR $g 48 850 984 580 42 '#FFFFFF'
Text $g '选择分类' 95 895 38 '#1F3440' $true
Text $g '编辑' 908 895 31 '#FFD36B' $true
$cats = @('餐饮', '交通', '购物', '娱乐', '住房', '医疗', '教育', '其他')
for ($i = 0; $i -lt 8; $i++) {
  $col = $i % 4; $row = [Math]::Floor($i / 4)
  $cx = 190 + $col * 235; $cy = 1045 + $row * 220
  $brush = Brush $(if ($i -eq 0) { '#FFF4D6' } else { '#F4F6F8' })
  $g.FillEllipse($brush, $cx - 70, $cy - 70, 140, 140)
  $brush.Dispose()
  Text $g $cats[$i].Substring(0, 1) ($cx - 70) ($cy - 30) 42 '#9AAAB5' $true 140 60 'Center'
  Text $g $cats[$i] ($cx - 70) ($cy + 78) 28 '#9AAAB5' $false 140 40 'Center'
}
FillRR $g 48 1480 984 132 42 '#FFFFFF'
Text $g '添加备注（选填）' 225 1517 38 '#9AAAB5'
FillRR $g 48 1690 984 104 28 '#FFB84D'
Text $g '保存账单' 0 1714 38 '#FFFFFF' $true 1080 54 'Center'
BottomTab $g '记账'
SavePng $bmp $g (Join-Path $Out 'page_add_bill.png')

# 日历页
$pair = NewPage 'calendar'
$bmp = $pair[0]; $g = $pair[1]
MonthSelector $g 165
FillRR $g 0 335 1080 790 0 '#FFFFFF'
$week = @('一', '二', '三', '四', '五', '六', '日')
for ($i = 0; $i -lt 7; $i++) { Text $g $week[$i] (55 + $i * 145) 370 34 $(if ($i -gt 4) { '#2176B8' } else { '#7A8B99' }) $false 80 45 'Center' }
$day = 1
for ($r = 0; $r -lt 5; $r++) {
  for ($c = 0; $c -lt 7; $c++) {
    if (($r -eq 0 -and $c -lt 2) -or $day -gt 30) { continue }
    $x = 55 + $c * 145; $y = 470 + $r * 150
    if ($day -eq 29) {
      $brush = Brush '#21A7A8'; $g.FillEllipse($brush, $x + 12, $y - 10, 80, 80); $brush.Dispose()
      Text $g '29' $x ($y + 2) 38 '#FFFFFF' $true 104 50 'Center'
    } else {
      Text $g $day $x $y 38 $(if ($c -gt 4) { '#2176B8' } else { '#1F3440' }) $false 104 50 'Center'
    }
    if ($day -eq 15) { Text $g '25' $x ($y + 54) 22 '#EF5B73' $true 104 32 'Center' }
    $day++
  }
}
FillRR $g 0 1145 1080 150 0 '#FFFFFF'
Text $g '收入' 100 1170 30 '#7A8B99'; Text $g '¥0.00' 85 1208 36 '#31B46B' $true
Text $g '支出' 500 1170 30 '#7A8B99'; Text $g '¥0.00' 485 1208 36 '#EF5B73' $true
Text $g '结余' 870 1170 30 '#7A8B99'; Text $g '+0.00' 860 1208 36 '#31B46B' $true
FillRR $g 0 1325 1080 220 0 '#FFFFFF'
Text $g '预算' 35 1370 36 '#1F3440' $true
Text $g '餐饮' 35 1438 31 '#1F3440'
Text $g '¥25.00 / ¥100.00' 790 1438 28 '#7A8B99' $false 240 40 'Far'
FillRR $g 35 1495 270 12 6 '#FF6B45'
FillRR $g 0 1575 1080 435 0 '#FFFFFF'
Text $g '今天' 35 1625 38 '#1F3440' $true
IconLine $g 'list' 480 1785 1.8 '#D7DEE5'
Text $g '当日暂无账单' 0 1880 32 '#7A8B99' $false 1080 50 'Center'
BottomTab $g '日历'
SavePng $bmp $g (Join-Path $Out 'page_calendar.png')

# 搜索页
$pair = NewPage 'search'
$bmp = $pair[0]; $g = $pair[1]
Text $g '‹' 82 180 58 '#1F3440'
IconLine $g 'list' 205 204 1 '#7A8B99'
Text $g '搜索备注 / 分类 / 金额' 0 192 42 '#9AAAB5' $false 1080 54 'Center'
Text $g '清空' 940 198 32 '#FFD36B' $true
Text $g '筛选条件' 48 310 38 '#1F3440' $true
FillRR $g 48 405 984 230 28 '#FFFFFF'; StrokeRR $g 48 405 984 230 28 '#E7F0EF' 2
Text $g '分类' 0 433 30 '#9AAAB5' $false 1080 45 'Center'
FillRR $g 88 505 904 78 39 '#FFFFFF'; StrokeRR $g 88 505 904 78 39 '#E7F0EF' 2
Text $g '全部分类' 125 520 34 '#9AAAB5'
FillRR $g 48 665 984 230 28 '#FFFFFF'; StrokeRR $g 48 665 984 230 28 '#E7F0EF' 2
Text $g '时间范围' 0 695 30 '#9AAAB5' $false 1080 45 'Center'
FillRR $g 88 765 420 78 39 '#FFFFFF'; StrokeRR $g 88 765 420 78 39 '#E7F0EF' 2
Text $g '开始日期' 88 782 34 '#9AAAB5' $false 420 45 'Center'
FillRR $g 552 765 420 78 39 '#FFFFFF'; StrokeRR $g 552 765 420 78 39 '#E7F0EF' 2
Text $g '结束日期' 552 782 34 '#9AAAB5' $false 420 45 'Center'
FillRR $g 0 930 1080 102 0 '#FFFFFF'
Text $g '结果 1 条' 48 958 34 '#7A8B99'
Text $g '收入 ¥0.00' 360 958 31 '#31B46B'
Text $g '支出 ¥25.00' 560 958 31 '#EF5B73'
Text $g '净额 ¥-25.00' 780 958 31 '#EF5B73'
Chip $g 548 1055 150 '全部' $true; Chip $g 725 1055 150 '收入'; Chip $g 900 1055 150 '支出'
Text $g '4月15日 星期三' 58 1222 34 '#7A8B99' $true
BillRow $g 48 1300
BottomTab $g '账单'
SavePng $bmp $g (Join-Path $Out 'page_search.png')

# 统计页
$pair = NewPage 'stats'
$bmp = $pair[0]; $g = $pair[1]
MonthSelector $g 165
SummaryCard $g 48 420 984 420 '¥25.00' '¥25.00'
FillRR $g 48 895 984 150 36 '#FFFFFF'
Text $g '本月结余' 95 930 32 '#9AAAB5'; Text $g '¥25.00' 95 970 38 '#EF5B73' $true
Text $g '近6月月均支出' 695 930 32 '#9AAAB5'; Text $g '¥4.17' 800 970 38 '#1F3440' $true
FillRR $g 330 1110 420 82 41 '#FFFFFF'
FillRR $g 342 1122 190 58 29 '#1F3440'; Text $g '结构' 342 1133 31 '#FFFFFF' $true 190 42 'Center'
Text $g '趋势' 540 1133 31 '#9AAAB5' $false 190 42 'Center'
FillRR $g 48 1230 984 650 38 '#FFFFFF'
Text $g '分类支出占比' 0 1272 38 '#1F3440' $true 1080 50 'Center'
Text $g '共 1 类，总支出 ¥25.00' 0 1325 28 '#9AAAB5' $false 1080 40 'Center'
$pen = PenC '#FF6B45' 78
$g.DrawEllipse($pen, 330, 1460, 420, 420)
$pen.Dispose()
Text $g '总支出' 0 1578 32 '#9AAAB5' $false 1080 45 'Center'
Text $g '¥25.00' 0 1648 38 '#1F3440' $true 1080 55 'Center'
FillRR $g 48 1915 984 132 34 '#FFFFFF'
Text $g '餐饮' 175 1951 34 '#1F3440' $true
Text $g '¥25.00' 760 1938 36 '#1F3440' $true 230 42 'Far'
FillRR $g 95 2028 880 12 6 '#FF6B45'
BottomTab $g '统计'
SavePng $bmp $g (Join-Path $Out 'page_stats.png')

# 设置页
$pair = NewPage 'settings'
$bmp = $pair[0]; $g = $pair[1]
Text $g '设置' 70 170 44 '#1F3440' $true
FillRR $g 48 300 984 126 38 '#FFFFFF'
Text $g '分类管理' 195 333 36 '#1F3440' $true
Text $g '自定义分类、排序' 650 340 28 '#7A8B99'
Text $g '月度预算' 48 485 34 '#1F3440' $true
FillRR $g 48 555 984 920 38 '#FFFFFF'
$budget = @(
  @('餐饮', '餐', '#FF6B45', '100.00'), @('交通', '交', '#39A8F2', '不限'), @('购物', '购', '#EF5B73', '不限'), @('娱乐', '娱', '#A845C5', '不限'),
  @('住房', '住', '#21A7A8', '不限'), @('医疗', '医', '#F04E4E', '不限'), @('教育', '学', '#5666C9', '不限'), @('其他', '···', '#78909C', '不限')
)
for ($i = 0; $i -lt 8; $i++) {
  $y = 620 + $i * 100
  $brush = Brush $budget[$i][2]
  $g.FillEllipse($brush, 78, $y - 22, 76, 76)
  $brush.Dispose()
  Text $g $budget[$i][1] 78 ($y - 9) 30 '#FFFFFF' $true 76 42 'Center'
  Text $g $budget[$i][0] 205 ($y - 3) 34 '#1F3440'
  Text $g '¥' 620 ($y - 3) 30 '#9AAAB5'
  Text $g $budget[$i][3] 830 ($y - 3) 32 $(if ($budget[$i][3] -eq '不限') { '#9AAAB5' } else { '#1F3440' }) $false 160 45 'Far'
}
FillRR $g 48 1545 984 102 34 '#FFD36B'
Text $g '保存预算设置' 0 1568 36 '#FFFFFF' $true 1080 54 'Center'
FillRR $g 48 1690 984 104 34 '#FFFFFF'; StrokeRR $g 48 1690 984 104 34 '#FFD36B' 2
Text $g '导出全部账单（CSV）' 0 1717 34 '#FFD36B' $true 1080 48 'Center'
FillRR $g 48 1845 984 104 34 '#FFFFFF'
Text $g '关于小金鱼记账' 195 1874 34 '#1F3440'
Text $g 'v1.0.0' 870 1874 30 '#9AAAB5'
BottomTab $g '设置'
SavePng $bmp $g (Join-Path $Out 'page_settings.png')

# 总览设计板
$pair = Canvas 1800 2400 '#F7FBFA'
$bmp = $pair[0]; $g = $pair[1]
Text $g '小金鱼记账 成品页面设计' 80 60 56 '#1F3440' $true
Text $g '基于当前应用截图重设：保留原有信息结构，替换为清水青绿 + 金鱼金的年轻化视觉。' 82 132 26 '#7A8B99'
$pages = @('page_home.png', 'page_add_bill.png', 'page_calendar.png', 'page_search.png', 'page_stats.png', 'page_settings.png')
for ($i = 0; $i -lt 6; $i++) {
  $img = [System.Drawing.Image]::FromFile((Join-Path $Out $pages[$i]))
  $col = $i % 3; $row = [Math]::Floor($i / 3)
  $dest = New-Object System.Drawing.Rectangle (90 + $col * 560), (220 + $row * 1020), 420, 910
  $g.DrawImage($img, $dest)
  $img.Dispose()
}
SavePng $bmp $g (Join-Path $Out 'xjy_finished_pages_board.png')

Write-Host \"Generated design pages in $Out\"
Write-Host \"Generated assets in $Assets\"
