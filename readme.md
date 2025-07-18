# Intro

- This project implements the Sobel Conv + pad + 7x7 Conv function

## 流水线卷积状态机

### 设计

- 128位输入是可以扩的

state:
IDLE: 全部归0
READ: 开始读buffer, 上面打pad, 左右打pad
MIDDLE_CONV: 中间卷积
BOTTOM_CONV: 底部卷积, 全部打0

- IDLE -> conv_en -> READ, or IDLE

- READ -> add_en -> MIDDLE_CONV, or READ

- MIDDLE_CONV -> bottom_en -> BOTTOM_CONV

- BOTTOM_CONV -> ~bottom_en -> MIDDLE_CONV, ~add_en -> READ

### Debug

- 看总体 √

- 状态机转换

- 输出状态有效

- 检查adder_tree √

## Sobel

## Hessian矩阵
