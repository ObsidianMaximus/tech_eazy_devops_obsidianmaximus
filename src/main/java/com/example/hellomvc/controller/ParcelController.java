package com.example.hellomvc.controller;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class ParcelController {

	@GetMapping("/parcel")
	public String hello(Model model) {
		return "here is a parcel";
	}
}
