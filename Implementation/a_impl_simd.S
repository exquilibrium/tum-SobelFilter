.global filter_asm_simd				//x0: Input-Bild(unsigned char*), x1: Output-Bild(unsigned char*), x2: Breite b(int), x3: Höhe h(int)
filter_asm_simd:
						//Konstanten:			
	sub w14, w2, 2
	add w14, w14, w14, lsl 1		//Maximaler Wert des Counters über die Breite für byteweise Berechnung
	sub w13, w14, 8				//Maximaler Wert des Counters über die Breite für SIMD-Berechnung
	add w15, w2, w2, lsl#1			//w15 = b * 3
	add w16, w15, #3			//w16 = b * 3 + 3
	add w17, w16, #3			//w17 = b * 3 + 6
	add w18, w16, w15			//w18 = 2 * (b * 3) + 3
	mov x10, x15, lsl#1			//w10 = b * 6
	mov x11, x16, lsl#1			//w11 = (b + 1) * 6

						//Berechnung der letzten Speicheradresse von x0
	mul w5, w2, w3				//w5 = b * h
	add w5, w5, w5, lsl#1			//w5 = b * h * 3
	sub w5, w5, w16, lsl#1			//x0 zeigt auf den Pixel links über dem berechneten Pixel -> letzte Adresse ist zwei Spalten und zwei Zeilen über dem Ende des Bildes
	add x5, x5, x0				//x5 = letzte Adresse

						//Vorbereitung des Ausgabe-Pointers und des Counters über die Breite des Bildes
	add x1, x1, x16				//Der erste beschriebene Pixel ist in der zweiten Spalte der zweiten Zeile
	mov w4, 0				//Counter = 0
	
.Lloop:						//Main-Loop
						//Test, ob noch 8 Werte oder mehr in der momentanen Zeile berechnet werden müssen
	cmp w4, w13
	b.gt .LByteLoop				//Sprung in die byteweise Verarbeitung der Farbkanäle

.LSIMDLoop:
	add w4, w4, 8				//Counter über die Breite wird inkrementiert
	
						//Berechnung des Algorithmus. q0 := A vertikal, q1 := A horizontal, 
						//q2: temp. Variable zum Laden neuer Werte, E_(x,y): Eingabebild an Stelle x,y
						//x,y: Koordinaten des momentan auszurechnenden Ausgabe-Pixels
	ldr q0, [x0]				//q0 = E_(x-1,y-1)
	uxtl v0.8h, v0.8b			//Erweiterung der ersten acht 8-Bit Werte auf 16-Bit Werte
	mov v1.16b, v0.16b

	ldr q2, [x0, #3]			//q2 = E_(x,y-1)
	ushll v2.8h, v2.8b, #1			//Erweiterung der ersten acht 8-Bit Werte auf 16-Bit Werte und gleichzeitiger Left Shift
	add v0.8h, v0.8h, v2.8h

	ldr q2, [x0, #6]			//q2 = E_(x+1,y-1)
	uxtl v2.8h, v2.8b
	add v0.8h, v0.8h, v2.8h
	sub v1.8h, v1.8h, v2.8h

	ldr q2, [x0, x15]			//q2 = E_(x-1,y)
	ushll v2.8h, v2.8b, #1
	add v1.8h, v1.8h, v2.8h

	ldr q2, [x0, x17]			//q2 = E_(x+1,y)
	ushll v2.8h, v2.8b, #1
	sub v1.8h, v1.8h, v2.8h

	ldr q2, [x0, x10]			//q2 = E_(x-1,y+1)
	uxtl v2.8h, v2.8b
	sub v0.8h, v0.8h, v2.8h
	add v1.8h, v1.8h, v2.8h

	ldr q2, [x0, x18]			//q2 = E_(x, y+1)
	ushll v2.8h, v2.8b, #1
	sub v0.8h, v0.8h, v2.8h

	ldr q2, [x0, x11]			//q2 = E_(x+1,y+1)
	uxtl v2.8h, v2.8b
	sub v0.8h, v0.8h, v2.8h
	sub v1.8h, v1.8h, v2.8h

	sxtl v2.4s, v1.4h			//Erweiterung der 16-Bit Werte auf 32-Bit Werte, um bei der späteren Quadrierung 
	sxtl2 v3.4s, v1.8h			//Overflows zu vermeiden. In den Lanes können auch negative Werte stehen, weswegen
	sxtl2 v1.4s, v0.8h			//hier die signed Instruction anstatt der unsigned Variante hergenommen wird.
	sxtl v0.4s, v0.4h			//q0 steht jetzt in q0 und q1, während q1 in q2 und q3 steht

	mul v0.4s, v0.4s, v0.4s			//Quadrierung aller 16 Werte
	mul v1.4s, v1.4s, v1.4s
	mul v2.4s, v2.4s, v2.4s
	mul v3.4s, v3.4s, v3.4s

	add v0.4s, v0.4s, v2.4s			//Addition des vertikalen und horizontalen Ergebnis
	add v1.4s, v1.4s, v3.4s

	add x0, x0, 8				//Pointer des Eingabebildes wird in dieser Schleife nicht mehr benötigt und deswegen inkrementiert 
	
//take square root
	ucvtf v1.4s, v1.4s			//Konvertierung zu float von beiden Registern
	ucvtf v0.4s, v0.4s
	fsqrt v1.4s, v1.4s			//Wurzel der Registern
	fsqrt v0.4s, v0.4s
	fcvtzu v0.4s, v0.4s			//Konvertierung zu Integer von beiden Registern
	fcvtzu v1.4s, v1.4s

	xtn v0.4h, v0.4s			//Konvertierung der Werte zu 16-Bit Integern.
	xtn2 v0.8h, v1.4s			//Ergebnis liegt in v0.

	movi v1.8h, 0xff			//Begrenzung der Werte auf 255 mit Hilfe von Bitweisen Operatoren, um die Werte zu 8-Bit Werten zu konvertieren
	cmhi v2.8h, v0.8h, v1.8h		//Erstellen einer Maske, die auf allen Lanes auf 1 gesetzt ist, wo der Wert in v0
	mvn v3.16b, v2.16b			//größer als 255 ist.
	and v0.16b, v3.16b, v0.16b
	and v1.16b, v1.16b, v2.16b
	orr v0.16b, v0.16b, v1.16b

	xtn v0.8b, v0.8h			//Casten der 16-Bit Werte zu 8-Bit Werten
	
	str d0, [x1], 8
	
	cmp x0, x5				//Überprüfung, ob x0 die maximale Adresse erreicht hat
	b.le .Lloop
	ret

.LByteLoop:					//byteweise Behandlung der Werte, die nicht mit SIMD behandelt werden können
	cmp w4, w14				//Test, ob der letzte Pixel einer Zeile erreicht wurde
	b.lt .LrestLoop
	add x0, x0, 6				//Eingabebild springt um zwei Pixel weiter
	add x1, x1, 6				//Ausgabebild springt um zwei Pixel weiter
	mov w4, 0				//Counter wird zurückgesetzt
	b .Lloop				//Nachdem eine neue Zeile erreicht wurde, wird wieder in den SIMD-Loop gesprungen
.LrestLoop:
	add w4, w4, 1

						//byteweise Berechnung des Algorithmus. w7 := A vertikal, w8 := A horizontal, 
						//w9: temporäre Variable zum Laden neuer Werte, E_(x,y): Eingabebild an Stelle x,y
						//x,y: Koordinaten des momentan auszurechnenden Ausgabe-Pixels
	ldrb w9, [x0]				//w9 = E_(x-1,y-1)		
	mov w7, w9
	mov w8, w9

	ldrb w9, [x0, #3]			//w9 = E_(x,y-1)
	add w7, w7, w9, lsl#1

	ldrb w9, [x0, #6]			//w9 = E_(x+1,y-1)
	add w7, w7, w9
	sub w8, w8, w9

	ldrb w9, [x0, x15]			//w9 = E_(x-1,y)
	add w8, w8, w9, lsl#1

	ldrb w9, [x0, x17]			//w9 = E_(x+1,y)
	sub w8, w8, w9, lsl#1

	ldrb w9, [x0, x10]			//w9 = E_(x-1,y+1)
	sub w7, w7, w9
	add w8, w8, w9

	ldrb w9, [x0, x18]			//w9 = E_(x,y+1)
	sub w7, w7, w9, lsl#1

	ldrb w9, [x0, x11]			//w9 = E_(x+1,y+1)
	sub w7, w7, w9
	sub w8, w8, w9

	mul w7, w7, w7				//w7 = w7^2
	mul w8, w8, w8				//w7 = w7^2

	add w6, w8, w7
	add x0, x0, 1				//Pointer des Eingabebildes wird inkrementiert

	scvtf s0, w6				//Konvertierung zu Float
	fsqrt s0, s0				//Berechnung der Wurzel
	fcvtzs w6, s0				//Konvertierung zu Integer

	mov w7, 255
	cmp w6, w7
	csel w6, w6, w7, le			//Begrenzung von w6 auf 255

	strb w6, [x1], 1			//Ergebnis wird gespeichert und x1 wird inkrementiert

	cmp x0, x5
	b.lt .LByteLoop				//Wenn x0 hier die maximale Adresse erreicht, wird der Algorithmus beendet
	ret


.global filter_asm_simd_ext			//x0: Input-Bild(unsigned char*), x1: Output-Bild(unsigned char*), x2: Breite b(int), x3: Höhe h(int)
filter_asm_simd_ext:				//Methode führt das Padding für die Randpixel aus und springt danach in den Kernalgorithmus
						//Konstanten:
	add w15, w2, w2, lsl#1			//w15 = b * 3
	add w16, w15, #3			//w16 = b * 3 + 3

						//Berechnung der Startadressen für die obere und untere horizontale Spiegelung
	mul w5, w2, w3				//w5 = b * h
	add w5, w5, w5, lsl#1			//w5 = b * h * 3
	sub w5, w5, w16, lsl#1			//w5 -= 6 *(b + 1)
	add x7, x5, 6				
	add x7, x7, x0				//x7: Adresse für die obere Zeile der unteren horizontalen Spiegelung
	add x6, x0, 3				//x6: Adresse für die obere Zeile der oberen horizontalen Spiegelung
						
						//Berechnung der letzten Adresse der oberen horizontalen Spiegelung
	sub x8, x15, 18
	add x8, x8, x0				//x8: Maximale Adresse für 16-byteweise Zugriffe
	add x12, x8, 21				//x12: Maximale Adresse für byteweise Zugriffe

.LprepHorizontal:				//Spiegelung von 16 Byte pro Schleifendurchlauf
	ldr q0, [x6, x15]
	str q0, [x6], 16
	ldr q0, [x7]
	str q0, [x7, x15]
	add x7, x7, 16
	cmp x6, x8
	b.lt .LprepHorizontal

.LprepHorizontalRest:				//Spiegelung von 1 Byte pro Schleifendurchlauf für die übrigen Werte
	cmp x6, x12
	b.ge .LendHor
	ldrb w9, [x6, x15]
	strb w9, [x6], 1
	ldrb w9, [x7]
	strb w9, [x7, x15]
	add x7, x7, 1
	b .LprepHorizontalRest
.LendHor:
						//Vorbereitungen für die vertikale Spiegelung
	mov x6, x0				//x6: Adresse des rechten vertikalen Randpixel
	sub w7, w2, 2
	add w7, w7, w7, lsl 1			//Offset von dem ersten Pixel einer Zeile zu dem vorletztem Pixel dieser Zeile
	add w8, w7, 3				//Offset von dem ersten Pixel einer Zeile zu dem letztem Pixel dieser Zeile

	mov w13, 0				//Counter über die Höhe
.LprepVertical:
	ldrb w9, [x6, x7]			//Spiegelung des Rot-Wertes auf beiden Seiten einer Zeile
	strb w9, [x6, x8]
	ldrb w9, [x6, 3]
	strb w9, [x6], 1

	ldrb w9, [x6, x7]			//Spiegelung des Grün-Wertes auf beiden Seiten einer Zeile
	strb w9, [x6, x8]
	ldrb w9, [x6, 3]
	strb w9, [x6], 1

	ldrb w9, [x6, x7]			//Spiegelung des Blau-Wertes auf beiden Seiten einer Zeile
	strb w9, [x6, x8]
	ldrb w9, [x6, 3]
	strb w9, [x6], 1

	add x6, x6, x8				//Inkrementierung des Pointers auf das erste Byte der nächsten Zeile
	
	add w13, w13, 1
	cmp w13, w3
	b.lt .LprepVertical
	
	str x30, [sp, -16]!
	bl filter_asm_simd			//Aufruf des Kernalgorithmus
	ldr x30, [sp], 16
	ret
