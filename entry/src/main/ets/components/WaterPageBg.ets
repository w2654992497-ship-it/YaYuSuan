@Component
export struct WaterPageBg {
  build() {
    Column()
      .width('100%')
      .height('100%')
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [
          [$r('app.color.color_bg'), 0.0],
          [$r('app.color.color_white'), 0.46],
          [$r('app.color.color_soft_blue'), 1.0]
        ]
      })
      .hitTestBehavior(HitTestMode.None)
  }
}

