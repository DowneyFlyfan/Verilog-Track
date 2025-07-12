import time
import torch
import torch.nn as nn
import nn.functional as F
import cv2
import numpy as np


ROI_SIZE = 480


class Frangi(nn.Module):
    def __init__(self):
        super().__init__()

        self.sobel_x = torch.tensor(
            [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], dtype=torch.float32, device="cuda"
        ).view(1, 1, 3, 3)
        self.sobel_y = torch.tensor(
            [[-1, -2, -1], [0, 0, 0], [1, 2, 1]], dtype=torch.float32, device="cuda"
        ).view(1, 1, 3, 3)
        self.sobel_xy = torch.cat((self.sobel_x, self.sobel_y), dim=0)
        with torch.no_grad():
            self.grad_conv = nn.Conv2d(
                in_channels=1,
                out_channels=2,
                kernel_size=3,
                padding=1,
                groups=1,
                bias=False,
                dtype=torch.float32,
                device="cuda",
            )
            self.sobel = nn.Parameter(self.sobel_xy.clone(), requires_grad=False)
            self.grad_conv.weight.copy_(self.sobel)

        self.g_xx = torch.tensor(
            [
                [
                    [
                        [0.0087, 0.0000, -0.0215, 0.0000, 0.0087],
                        [0.0392, 0.0000, -0.0965, 0.0000, 0.0392],
                        [0.0646, 0.0000, -0.1592, 0.0000, 0.0646],
                        [0.0392, 0.0000, -0.0965, 0.0000, 0.0392],
                        [0.0087, 0.0000, -0.0215, 0.0000, 0.0087],
                    ]
                ]
            ],
            dtype=torch.float32,
        ).to("cuda")
        self.g_xy = torch.tensor(
            [
                [
                    [
                        [0.0117, 0.0261, -0.0000, -0.0261, -0.0117],
                        [0.0261, 0.0585, -0.0000, -0.0585, -0.0261],
                        [-0.0000, -0.0000, 0.0000, 0.0000, 0.0000],
                        [-0.0261, -0.0585, 0.0000, 0.0585, 0.0261],
                        [-0.0117, -0.0261, 0.0000, 0.0261, 0.0117],
                    ]
                ]
            ],
            dtype=torch.float32,
        ).to("cuda")
        self.g_yy = torch.tensor(
            [
                [
                    [
                        [0.0087, 0.0392, 0.0646, 0.0392, 0.0087],
                        [0.0000, 0.0000, 0.0000, 0.0000, 0.0000],
                        [-0.0215, -0.0965, -0.1592, -0.0965, -0.0215],
                        [0.0000, 0.0000, 0.0000, 0.0000, 0.0000],
                        [0.0087, 0.0392, 0.0646, 0.0392, 0.0087],
                    ]
                ]
            ],
            dtype=torch.float32,
        ).to("cuda")
        self.combined_kernel = torch.cat([self.g_xx, self.g_xy, self.g_yy], dim=0)

        with torch.no_grad():
            self.response_conv = nn.Conv2d(
                in_channels=1,
                out_channels=3,
                kernel_size=5,
                padding=2,
                groups=1,
                bias=False,
                dtype=torch.float32,
                device="cuda",
            )
            self.response_conv.weight.data = self.combined_kernel
            self.response_conv.weight.requires_grad = False

        tril_mask = torch.tril(torch.ones((ROI_SIZE, ROI_SIZE), device="cuda"))
        self.tril_x = nn.Parameter(tril_mask.clone(), requires_grad=False)
        self.tril_y = nn.Parameter(tril_mask.clone(), requires_grad=False)
        self.linear_x = nn.Linear(ROI_SIZE, ROI_SIZE, bias=False, device="cuda")
        self.linear_y = nn.Linear(ROI_SIZE, ROI_SIZE, bias=False, device="cuda")
        with torch.no_grad():
            self.linear_x.weight.copy_(self.tril_x)
            self.linear_y.weight.copy_(self.tril_y)

        self.valid_mask = torch.zeros(
            (1, ROI_SIZE, ROI_SIZE), dtype=torch.float, device="cuda"
        )
        self.valid_mask[..., 10:-10, 10:-10] = 1.0

    def compute_gradient(self, image):
        grad_xy = self.grad_conv(image)
        grad_tensor = torch.sum(torch.abs(grad_xy), dim=1, keepdim=True)
        grad_tensor = grad_tensor / grad_tensor.max()

        grad_tensor[0, 0, -5:, :] = 0
        grad_tensor[0, 0, :5, :] = 0
        grad_tensor[0, 0, :, -5:] = 0
        grad_tensor[0, 0, :, :5] = 0

        return grad_tensor

    def response(self, x, mask_img):
        D_conbined = self.response_conv(x)

        Dxx = D_conbined[:, 0:1, :, :]
        Dxy = D_conbined[:, 1:2, :, :]
        Dyy = D_conbined[:, 2:3, :, :]

        trace = Dxx + Dyy
        det = (Dxx * Dyy) - (Dxy * Dxy)
        sqrt_term = torch.relu((trace * trace) - (4 * (det * det)))
        lambda1 = trace - sqrt_term
        lambda2 = trace + sqrt_term

        filtered = (lambda2.abs() + lambda1.abs()) * (lambda2 - lambda1)
        return filtered * mask_img

    def compute_cumsum(self, response_result):
        response = response_result[0, 0, :, :]

        x_cumsum = torch.cumsum(response, dim=0)
        resp_cumsum = torch.cumsum(x_cumsum, dim=1)

        return resp_cumsum

    def forward(self, image_clone, mask_img):
        grad_tensor = self.compute_gradient(image_clone)
        response = self.response(grad_tensor, mask_img)
        resp_cumsum = self.compute_cumsum(response)
        cv2.imshow(
            "grad_tensor",
            grad_tensor.clone().detach().squeeze().squeeze().cpu().numpy(),
        )
        cv2.waitKey(1)
        cv2.imshow(
            "response",
            (response.clone() * 255 / torch.max(response.clone()))
            .detach()
            .squeeze()
            .squeeze()
            .cpu()
            .numpy(),
        )
        cv2.waitKey(1)
        return resp_cumsum, response
