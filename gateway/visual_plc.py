"""
ALRISA - OpenPLC Visual Studio (Visual Drag & Drop Ladder Editor)
A product by Alfatech Solutions IDN.
Dilengkapi:
- Toolbar Palette: Kontak NO (-| |-), NC (|/|), Coil Standard, Set (S), Reset (R), Timer TON.
- Real-time PLC Ladder Execution Engine (Kabel & Coil Menyala Hijau saat teraliri daya).
- Sinkronisasi Live Dua Arah ke Aplikasi HP ALRISA & Web Dashboard via MQTT.
"""

import json
import threading
import time
import tkinter as tk
from tkinter import font, messagebox, simpledialog
import paho.mqtt.client as mqtt

# Menghubungkan ke Private Broker Lokal di Laptop
BROKER = "127.0.0.1"
PORT = 1883

class LadderElement:
    def __init__(self, elem_type, name, address=""):
        self.type = elem_type  # 'NO', 'NC', 'COIL', 'COIL_S', 'COIL_R', 'TON'
        self.name = name
        self.address = address
        self.preset_ms = 3000   # untuk TON
        self.elapsed_ms = 0
        self.state = False      # status evaluasi daya

class LadderRung:
    def __init__(self, rung_id):
        self.id = rung_id
        self.elements = []      # list of LadderElement
        self.branch_elements = [] # list cabang paralel (OR)

class OpenPLCLiteApp:
    def __init__(self, root):
        self.root = root
        self.root.title("ALRISA - OpenPLC Studio (Visual Ladder Simulator) - Alfatech Solutions IDN.")
        self.root.geometry("1100x740")
        self.root.configure(bg="#1E1E2E")
        self.root.minsize(980, 650)

        # State I/O PLC (%IX dan %QX)
        self.inputs = {
            "%IX0.0": False,  # Tombol Fisik Start
            "%IX0.1": False,  # Tombol Fisik Stop
            "%IX0.2": False,  # Sensor Pagar Limit
            "%IX0.3": False,  # Sensor Level Toren
        }
        self.outputs = {
            "%QX0.0": False,  # Lampu Teras
            "%QX0.1": False,  # Pagar Utama
            "%QX0.2": False,  # Pintu Geser
            "%QX0.3": False,  # Gorden
            "%QX0.4": False,  # Pompa Toren
        }

        # Device mapping ke MQTT
        self.addr_to_device = {
            "%QX0.0": "lampu_teras",
            "%QX0.1": "pagar",
            "%QX0.2": "pintu_geser",
            "%QX0.3": "gorden",
            "%QX0.4": "pompa_toren",
        }
        self.device_to_addr = {v: k for k, v in self.addr_to_device.items()}

        # Ladder Program Data
        self.rungs = []
        self._init_default_rungs()

        # Selection & Dragging state
        self.selected_tool = None
        self.dragged_item = None
        self.selected_element = None

        self._setup_ui()
        self._start_mqtt()
        self._start_plc_solver_loop()

    def _init_default_rungs(self):
        # Rung 1: Lampu Teras (Start / Remote OR Tombol) -> Stop NC -> S Lampu
        r1 = LadderRung(1)
        r1.elements = [
            LadderElement("NO", "Tombol", "%IX0.0"),
            LadderElement("NC", "TombolStop", "%IX0.1"),
            LadderElement("COIL_S", "LampuTeras", "%QX0.0"),
        ]
        r1.branch_elements = [
            LadderElement("NO", "RemoteApp", "%QX0.0")
        ]

        # Rung 2: Reset Lampu Teras saat Stop ditekan
        r2 = LadderRung(2)
        r2.elements = [
            LadderElement("NO", "TombolStop", "%IX0.1"),
            LadderElement("COIL_R", "LampuTeras", "%QX0.0"),
        ]

        # Rung 3: Kontrol Pagar Utama
        r3 = LadderRung(3)
        r3.elements = [
            LadderElement("NO", "MotorPagar", "%QX0.1"),
            LadderElement("COIL", "Pagar", "%QX0.1"),
        ]

        self.rungs = [r1, r2, r3]

    def _setup_ui(self):
        # 1. Header Toolbar Studio
        header = tk.Frame(self.root, bg="#181825", pady=8, padx=16)
        header.pack(fill=tk.X)

        title = tk.Label(
            header,
            text="⚡ OPENPLC LITE STUDIO",
            font=("Segoe UI", 15, "bold"),
            fg="#89B4FA",
            bg="#181825",
        )
        title.pack(side=tk.LEFT)

        self.lbl_status = tk.Label(
            header,
            text="● MQTT ONLINE (broker.emqx.io)",
            font=("Segoe UI", 10, "bold"),
            fg="#A6E3A1",
            bg="#181825",
        )
        self.lbl_status.pack(side=tk.RIGHT)

        # 2. Tool Palette (Drag & Drop / Add Elements)
        palette = tk.Frame(self.root, bg="#313244", pady=6, padx=12)
        palette.pack(fill=tk.X)

        tk.Label(palette, text="PALETTE ELEMEN: ", font=("Segoe UI", 9, "bold"), fg="#CDD6F4", bg="#313244").pack(side=tk.LEFT, padx=(0, 6))

        tools = [
            ("NO -| |-", "NO", "#A6E3A1"),
            ("NC -|/|-", "NC", "#F38BA8"),
            ("Coil -( )-", "COIL", "#89B4FA"),
            ("Set -( S )-", "COIL_S", "#F9E2AF"),
            ("Reset -( R )-", "COIL_R", "#CBA6F7"),
            ("Timer [TON]", "TON", "#94E2D5"),
        ]

        self.tool_buttons = {}
        for label, tool_type, col in tools:
            btn = tk.Button(
                palette,
                text=label,
                font=("Consolas", 9, "bold"),
                bg="#181825",
                fg=col,
                relief=tk.FLAT,
                padx=8,
                pady=4,
                activebackground=col,
                activeforeground="#11111B",
                command=lambda t=tool_type: self._select_palette_tool(t),
            )
            btn.pack(side=tk.LEFT, padx=3)
            self.tool_buttons[tool_type] = btn

        # Tombol Aksi Rung
        tk.Frame(palette, width=15, bg="#313244").pack(side=tk.LEFT)
        btn_add_rung = tk.Button(
            palette, text="+ Tambah Rung", bg="#45475A", fg="#CDD6F4", font=("Segoe UI", 9, "bold"),
            relief=tk.FLAT, padx=6, pady=4, command=self._add_new_rung
        )
        btn_add_rung.pack(side=tk.LEFT, padx=3)

        btn_clear = tk.Button(
            palette, text="Reset Default", bg="#45475A", fg="#BAC2DE", font=("Segoe UI", 8),
            relief=tk.FLAT, padx=6, pady=4, command=self._reset_default
        )
        btn_clear.pack(side=tk.RIGHT, padx=3)

        # 3. Main Split View: Canvas Ladder (Kiri) + Live Hardware Panel (Kanan)
        main_split = tk.Frame(self.root, bg="#1E1E2E", padx=12, pady=10)
        main_split.pack(fill=tk.BOTH, expand=True)

        # Kanvas Ladder dengan Scrollbar
        canvas_container = tk.Frame(main_split, bg="#11111B", bd=1, relief=tk.SOLID)
        canvas_container.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 8))

        self.canvas = tk.Canvas(canvas_container, bg="#11111B", highlightthickness=0)
        vbar = tk.Scrollbar(canvas_container, orient=tk.VERTICAL, command=self.canvas.yview)
        self.canvas.configure(yscrollcommand=vbar.set)

        vbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        self.canvas.bind("<Button-1>", self._on_canvas_click)
        self.canvas.bind("<Double-Button-1>", self._on_canvas_double_click)

        # Panel Kanan: Perangkat Fisik & Tombol Interaktif
        right_panel = tk.Frame(main_split, width=320, bg="#181825", padx=12, pady=10)
        right_panel.pack(side=tk.RIGHT, fill=tk.Y)
        right_panel.pack_propagate(False)

        tk.Label(
            right_panel, text="🎛️ SIMULASI FISIK RUMAH", font=("Segoe UI", 11, "bold"), fg="#89B4FA", bg="#181825"
        ).pack(anchor=tk.W, pady=(0, 8))

        # Tombol Fisik
        tk.Label(right_panel, text="INPUT FISIK (Tekan untuk Uji):", font=("Segoe UI", 8, "bold"), fg="#A6ADC8", bg="#181825").pack(anchor=tk.W)

        btn_t_start = tk.Button(
            right_panel, text="🔘 Tombol Start %IX0.0 (Momentary)", bg="#A6E3A1", fg="#11111B",
            font=("Segoe UI", 9, "bold"), relief=tk.FLAT, pady=5, command=lambda: self._pulse_input("%IX0.0")
        )
        btn_t_start.pack(fill=tk.X, pady=3)

        btn_t_stop = tk.Button(
            right_panel, text="🛑 Tombol Stop %IX0.1 (E-Stop)", bg="#F38BA8", fg="#11111B",
            font=("Segoe UI", 9, "bold"), relief=tk.FLAT, pady=5, command=lambda: self._pulse_input("%IX0.1")
        )
        btn_t_stop.pack(fill=tk.X, pady=3)

        tk.Frame(right_panel, height=1, bg="#313244").pack(fill=tk.X, pady=10)

        # Output Perangkat Nyata (Sinkron dengan HP)
        tk.Label(right_panel, text="OUTPUT PERANGKAT (%QX):", font=("Segoe UI", 8, "bold"), fg="#A6ADC8", bg="#181825").pack(anchor=tk.W)

        self.dev_indicators = {}
        devices_list = [
            ("Lampu Teras", "%QX0.0", "💡"),
            ("Pagar Utama", "%QX0.1", "🚪"),
            ("Pintu Geser", "%QX0.2", "🚪"),
            ("Gorden Kamar", "%QX0.3", "🪟"),
            ("Pompa Toren", "%QX0.4", "💧"),
        ]

        for name, addr, icon in devices_list:
            row = tk.Frame(right_panel, bg="#313244", pady=6, padx=8)
            row.pack(fill=tk.X, pady=3)

            tk.Label(row, text=f"{icon} {name}\n({addr})", font=("Segoe UI", 9, "bold"), fg="#CDD6F4", bg="#313244", justify=tk.LEFT).pack(side=tk.LEFT)
            lbl_val = tk.Label(row, text="MATI", font=("Segoe UI", 9, "bold"), fg="#6C7086", bg="#313244")
            lbl_val.pack(side=tk.RIGHT)
            self.dev_indicators[addr] = lbl_val

        # Info Box di Bawah Panel Kanan
        info_box = tk.Label(
            right_panel,
            text="💡 PETUNJUK STUDIO:\n• Klik Tool di atas -> Klik Rung untuk tambah elemen.\n• Double-click elemen untuk edit alamat/nama.\n• Tekan HP Anda -> Ladder akan menyala hijau live!",
            font=("Segoe UI", 8),
            fg="#9399B2",
            bg="#181825",
            justify=tk.LEFT,
            pady=8
        )
        info_box.pack(side=tk.BOTTOM, fill=tk.X)

    def _select_palette_tool(self, tool_type):
        if self.selected_tool == tool_type:
            self.selected_tool = None
            self.tool_buttons[tool_type].config(bg="#181825", fg="#CDD6F4")
        else:
            if self.selected_tool:
                self.tool_buttons[self.selected_tool].config(bg="#181825")
            self.selected_tool = tool_type
            self.tool_buttons[tool_type].config(bg="#45475A")

    def _add_new_rung(self):
        new_id = len(self.rungs) + 1
        new_rung = LadderRung(new_id)
        # default coil baru
        new_rung.elements = [
            LadderElement("NO", f"In_{new_id}", "%IX0.0"),
            LadderElement("COIL", f"Out_{new_id}", f"%QX0.{new_id % 5}"),
        ]
        self.rungs.append(new_rung)
        self._render_ladder()

    def _reset_default(self):
        self._init_default_rungs()
        self._render_ladder()

    def _pulse_input(self, addr):
        self.inputs[addr] = True
        self.root.after(400, lambda: self._release_input(addr))

    def _release_input(self, addr):
        self.inputs[addr] = False

    def _render_ladder(self):
        c = self.canvas
        c.delete("all")

        start_y = 30
        rail_left = 40
        rail_right = 680

        # Gambar Power Rails Kiri & Kanan
        total_height = max(550, len(self.rungs) * 160 + 50)
        c.create_line(rail_left, 10, rail_left, total_height, fill="#89B4FA", width=4)
        c.create_line(rail_right, 10, rail_right, total_height, fill="#89B4FA", width=4)

        self.element_hitboxes = []

        current_y = start_y
        for rung_idx, rung in enumerate(self.rungs):
            rung_y = current_y + 40
            c.create_text(rail_left + 10, current_y + 10, text=f"Rung {rung.id}", fill="#6C7086", font=("Segoe UI", 9, "bold"), anchor=tk.W)

            # Tombol tambah cabang paralel & hapus rung
            btn_add_br = c.create_text(rail_left + 75, current_y + 10, text="[+ Cabang OR]", fill="#89B4FA", font=("Segoe UI", 8, "underline"), anchor=tk.W)
            btn_del_r = c.create_text(rail_right - 60, current_y + 10, text="[Hapus Rung]", fill="#F38BA8", font=("Segoe UI", 8, "underline"), anchor=tk.W)
            self.element_hitboxes.append(("ADD_BRANCH", rung_idx, c.bbox(btn_add_br)))
            self.element_hitboxes.append(("DEL_RUNG", rung_idx, c.bbox(btn_del_r)))

            # Evaluasi aliran listrik rung
            power_flow = True
            wire_color = "#A6E3A1" if power_flow else "#45475A"

            # Jalur Utama Seri
            x_cursor = rail_left
            elem_spacing = (rail_right - rail_left - 80) / max(1, len(rung.elements))

            for elem_idx, elem in enumerate(rung.elements):
                # Hitung status elemen
                elem_state = self._eval_element(elem)
                elem.state = elem_state

                next_x = x_cursor + elem_spacing
                mid_x = (x_cursor + next_x) / 2

                # Garis penghubung kawat
                wire_col = "#A6E3A1" if power_flow else "#45475A"
                c.create_line(x_cursor, rung_y, mid_x - 25, rung_y, fill=wire_col, width=2)

                # Gambar Elemen Grafis
                box = self._draw_symbol(mid_x, rung_y, elem, power_flow)
                self.element_hitboxes.append(("ELEMENT", (rung_idx, "MAIN", elem_idx), box))

                if not elem_state and "COIL" not in elem.type:
                    power_flow = False

                c.create_line(mid_x + 25, rung_y, next_x, rung_y, fill="#A6E3A1" if power_flow else "#45475A", width=2)
                x_cursor = next_x

            # Hubungkan ujung kawat ke rel kanan
            c.create_line(x_cursor, rung_y, rail_right, rung_y, fill="#A6E3A1" if power_flow else "#45475A", width=2)

            # Jika ada cabang paralel (OR)
            branch_y = rung_y + 45
            if rung.branch_elements:
                br_elem = rung.branch_elements[0]
                br_state = self._eval_element(br_elem)
                br_elem.state = br_state

                br_mid_x = rail_left + 120
                c.create_line(rail_left + 20, rung_y, rail_left + 20, branch_y, fill="#A6E3A1" if br_state else "#45475A", width=2)
                c.create_line(rail_left + 20, branch_y, br_mid_x - 25, branch_y, fill="#A6E3A1" if br_state else "#45475A", width=2)

                box = self._draw_symbol(br_mid_x, branch_y, br_elem, br_state)
                self.element_hitboxes.append(("ELEMENT", (rung_idx, "BRANCH", 0), box))

                c.create_line(br_mid_x + 25, branch_y, rail_left + 220, branch_y, fill="#A6E3A1" if br_state else "#45475A", width=2)
                c.create_line(rail_left + 220, branch_y, rail_left + 220, rung_y, fill="#A6E3A1" if br_state else "#45475A", width=2)

            current_y += 140 if rung.branch_elements else 105

        c.configure(scrollregion=(0, 0, rail_right + 50, current_y + 50))

    def _draw_symbol(self, cx, cy, elem, power_active):
        c = self.canvas
        col = "#A6E3A1" if elem.state else "#BAC2DE"
        bg_card = "#313244" if not elem.state else "#1e3a29"

        # Frame pembungkus simbol
        c.create_rectangle(cx - 24, cy - 20, cx + 24, cy + 20, fill=bg_card, outline=col, width=1)

        if elem.type == "NO":
            c.create_line(cx - 12, cy - 12, cx - 12, cy + 12, fill=col, width=2)
            c.create_line(cx + 12, cy - 12, cx + 12, cy + 12, fill=col, width=2)
        elif elem.type == "NC":
            c.create_line(cx - 12, cy - 12, cx - 12, cy + 12, fill=col, width=2)
            c.create_line(cx + 12, cy - 12, cx + 12, cy + 12, fill=col, width=2)
            c.create_line(cx - 12, cy + 12, cx + 12, cy - 12, fill="#F38BA8", width=2)
        elif elem.type == "COIL":
            c.create_oval(cx - 16, cy - 14, cx + 16, cy + 14, outline=col, width=2)
        elif elem.type == "COIL_S":
            c.create_oval(cx - 16, cy - 14, cx + 16, cy + 14, outline=col, width=2)
            c.create_text(cx, cy, text="S", fill=col, font=("Segoe UI", 9, "bold"))
        elif elem.type == "COIL_R":
            c.create_oval(cx - 16, cy - 14, cx + 16, cy + 14, outline=col, width=2)
            c.create_text(cx, cy, text="R", fill=col, font=("Segoe UI", 9, "bold"))
        elif elem.type == "TON":
            c.create_rectangle(cx - 22, cy - 14, cx + 22, cy + 14, outline=col, width=2)
            c.create_text(cx, cy, text="TON", fill=col, font=("Segoe UI", 8, "bold"))

        # Label Nama & Alamat di bawahnya
        c.create_text(cx, cy - 27, text=elem.name, fill="#CDD6F4", font=("Segoe UI", 8, "bold"))
        c.create_text(cx, cy + 28, text=elem.address, fill="#89B4FA", font=("Consolas", 7))

        return (cx - 25, cy - 32, cx + 25, cy + 35)

    def _eval_element(self, elem):
        # Baca nilai variabel
        val = False
        if elem.address in self.inputs:
            val = self.inputs[elem.address]
        elif elem.address in self.outputs:
            val = self.outputs[elem.address]

        if elem.type == "NO":
            return val
        elif elem.type == "NC":
            return not val
        elif elem.type in ["COIL", "COIL_S", "COIL_R"]:
            return val
        return val

    def _on_canvas_click(self, event):
        x = self.canvas.canvasx(event.x)
        y = self.canvas.canvasy(event.y)

        # Cek klik tombol aksi
        for item_type, data, bbox in self.element_hitboxes:
            if bbox and bbox[0] <= x <= bbox[2] and bbox[1] <= y <= bbox[3]:
                if item_type == "ADD_BRANCH":
                    rung = self.rungs[data]
                    rung.branch_elements = [LadderElement("NO", "Cabang_Baru", "%IX0.0")]
                    self._render_ladder()
                    return
                elif item_type == "DEL_RUNG":
                    if len(self.rungs) > 1:
                        del self.rungs[data]
                        self._render_ladder()
                    return
                elif item_type == "ELEMENT":
                    # Jika sedang pilih tool dari palette, ganti tipe elemen ini
                    if self.selected_tool:
                        rung_idx, branch_type, elem_idx = data
                        target = self.rungs[rung_idx].elements[elem_idx] if branch_type == "MAIN" else self.rungs[rung_idx].branch_elements[0]
                        target.type = self.selected_tool
                        self._render_ladder()
                    return

    def _on_canvas_double_click(self, event):
        x = self.canvas.canvasx(event.x)
        y = self.canvas.canvasy(event.y)

        for item_type, data, bbox in self.element_hitboxes:
            if item_type == "ELEMENT" and bbox[0] <= x <= bbox[2] and bbox[1] <= y <= bbox[3]:
                rung_idx, branch_type, elem_idx = data
                target = self.rungs[rung_idx].elements[elem_idx] if branch_type == "MAIN" else self.rungs[rung_idx].branch_elements[0]
                self._open_element_editor(target)
                return

    def _open_element_editor(self, elem):
        # Dialog Edit Elemen Sederhana & Cepat
        edit_win = tk.Toplevel(self.root)
        edit_win.title(f"Edit Elemen: {elem.name}")
        edit_win.geometry("340x260")
        edit_win.configure(bg="#1E1E2E", padx=16, pady=16)
        edit_win.transient(self.root)
        edit_win.grab_set()

        tk.Label(edit_win, text="Nama Variabel:", font=("Segoe UI", 9, "bold"), fg="#CDD6F4", bg="#1E1E2E").pack(anchor=tk.W)
        entry_name = tk.Entry(edit_win, font=("Segoe UI", 10), bg="#313244", fg="#CDD6F4", relief=tk.FLAT)
        entry_name.insert(0, elem.name)
        entry_name.pack(fill=tk.X, pady=(2, 10))

        tk.Label(edit_win, text="Alamat Hardware (%IX atau %QX):", font=("Segoe UI", 9, "bold"), fg="#CDD6F4", bg="#1E1E2E").pack(anchor=tk.W)
        entry_addr = tk.Entry(edit_win, font=("Consolas", 10), bg="#313244", fg="#89B4FA", relief=tk.FLAT)
        entry_addr.insert(0, elem.address)
        entry_addr.pack(fill=tk.X, pady=(2, 10))

        tk.Label(edit_win, text="Pilihan Cepat Alamat Perangkat:", font=("Segoe UI", 8), fg="#A6ADC8", bg="#1E1E2E").pack(anchor=tk.W)
        quick_frame = tk.Frame(edit_win, bg="#1E1E2E")
        quick_frame.pack(fill=tk.X, pady=4)

        for txt, ad in [("Lampu %QX0.0", "%QX0.0"), ("Pagar %QX0.1", "%QX0.1"), ("Tombol %IX0.0", "%IX0.0"), ("Stop %IX0.1", "%IX0.1")]:
            tk.Button(
                quick_frame, text=txt, font=("Segoe UI", 7), bg="#45475A", fg="#BAC2DE", relief=tk.FLAT,
                command=lambda a=ad: [entry_addr.delete(0, tk.END), entry_addr.insert(0, a)]
            ).pack(side=tk.LEFT, padx=2)

        def save_and_close():
            elem.name = entry_name.get().strip() or elem.name
            elem.address = entry_addr.get().strip() or elem.address
            edit_win.destroy()
            self._render_ladder()

        tk.Button(
            edit_win, text="Simpan Perubahan", bg="#A6E3A1", fg="#11111B", font=("Segoe UI", 10, "bold"),
            relief=tk.FLAT, pady=6, command=save_and_close
        ).pack(fill=tk.X, pady=(14, 0))

    def _start_plc_solver_loop(self):
        # Loop eksekusi PLC 50ms (Detak Jantung Ladder)
        def cycle():
            self._solve_ladder_logic()
            self._update_hardware_indicators()
            self._render_ladder()
            self.root.after(50, cycle)

        self.root.after(100, cycle)

    def _solve_ladder_logic(self):
        # Eksekusi Rung demi Rung
        for rung in self.rungs:
            power = True

            # Cabang paralel (OR)
            branch_or = False
            if rung.branch_elements:
                branch_or = self._eval_element(rung.branch_elements[0])

            # Rung seri
            first_element = True
            for elem in rung.elements:
                if "COIL" in elem.type:
                    # Jalankan aksi coil
                    if elem.type == "COIL":
                        if elem.address in self.outputs:
                            self.outputs[elem.address] = power
                    elif elem.type == "COIL_S" and power:
                        if elem.address in self.outputs:
                            self.outputs[elem.address] = True
                    elif elem.type == "COIL_R" and power:
                        if elem.address in self.outputs:
                            self.outputs[elem.address] = False
                else:
                    st = self._eval_element(elem)
                    if first_element and rung.branch_elements:
                        st = st or branch_or
                        first_element = False

                    if not st:
                        power = False

    def _update_hardware_indicators(self):
        for addr, lbl in self.dev_indicators.items():
            is_on = self.outputs.get(addr, False)
            if is_on:
                lbl.config(text="MENYALA", fg="#A6E3A1")
            else:
                lbl.config(text="MATI", fg="#6C7086")

    def _start_mqtt(self):
        self.mqtt_client = mqtt.Client(client_id="nexora-openplc-lite")
        self.mqtt_client.on_connect = self._on_mqtt_connect
        self.mqtt_client.on_message = self._on_mqtt_message

        threading.Thread(target=self._mqtt_worker, daemon=True).start()

    def _mqtt_worker(self):
        try:
            self.mqtt_client.connect(BROKER, PORT, 60)
            self.mqtt_client.loop_forever()
        except Exception:
            pass

    def _on_mqtt_connect(self, client, userdata, flags, rc):
        if rc == 0:
            client.subscribe("alrisa/+/set")
            client.subscribe("nexora/+/set")

    def _on_mqtt_message(self, client, userdata, msg):
        try:
            topic = msg.topic
            payload_str = msg.payload.decode('utf-8')
            parts = topic.split("/")
            if len(parts) < 3: return
            device = parts[1]

            is_on = False
            try:
                payload = json.loads(payload_str)
                if isinstance(payload, dict):
                    is_on = bool(payload.get("state", False))
                else:
                    is_on = bool(payload)
            except Exception:
                upper = payload_str.upper()
                is_on = ("OPEN" in upper or "TRUE" in upper or "1" in upper or "ON" in upper)

            # Map device HP ke alamat %QX
            if device in self.device_to_addr:
                addr = self.device_to_addr[device]
                self.outputs[addr] = is_on

                # Balas ACK /state ke HP & Web Dashboard (kedua prefix)
                ack = json.dumps({"state": is_on, "value": 85 if is_on else 0, "timestamp": int(time.time())})
                client.publish(f"alrisa/{device}/state", ack)
                client.publish(f"nexora/{device}/state", ack)
        except Exception:
            pass

if __name__ == "__main__":
    root = tk.Tk()
    app = OpenPLCLiteApp(root)
    root.mainloop()
