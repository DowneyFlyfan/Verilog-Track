# Intro

- This project implements the Sobel Conv + pad + 7x7 Conv function

## 流水线卷积状态机

1. 怎么打pad?

- 128位输入是可以扩的

state:
0: IDLE
1: READ: 开始读buffer, 上面打pad, 左右打pad
2: SIDE_CONV: 两侧卷积, 一次数据读入长度凑不够卷积长度, 就把两侧的都卷了来弥补这个长度
3: MIDDLE_CONV: 中间卷积

IDLE -> ~add_en, read_en -> READ
READ -> add_en  -> SIDE_CONV
SIDE_CONV -> (w_idx = PAD_SIZE -> middle_en) -> MIDDLE_CONV
SIDE_CONV -> ~add_en -> READ
MIDDLE_CONV -> ~middle_en -> SIDE_CONV

## Sobel

- 一次性读入128 bit数

## Hessian矩阵
