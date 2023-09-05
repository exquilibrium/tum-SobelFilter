.global filter_asm			//x0: Input-Bild(unsigned char*), x1: Output-Bild(unsigned char*), x2: Breite(int), x3: Höhe(int)
filter_asm:
					//Konstanten:
	sub w14, w2, 2				
	add w14, w14, w14, lsl 1	//w14 = 3 * (width - 2)
	add w15, w2, w2, lsl#1		//w15 = width * 3
	add w16, w15, #3		//w16 = width * 3 + 3
	add w17, w16, #3		//w17 = width * 3 + 6
	add w18, w16, w15		//w18 = 2 * (width * 3) + 3
	mov w10, w15, lsl#1		//w10 = width * 6
	mov w11, w16, lsl#1		//w11 = (width + 1) * 6

					//Berechnung der letzten Speicheradresse von x0
	mul w5, w2, w3			//w5 = width * height
	add w5, w5, w5, lsl#1		//w5 = w * h * 3
	sub w5, w5, w16, lsl#1		//x0 zeigt auf den Pixel links über dem berechneten Pixel -> letzte Adresse ist zwei Spalten und zwei Zeilen über dem Ende des Bildes
	add x5, x5, x0			//x5 = letzte Adresse

					//Vorbereitung des Ausgabe-Pointers und des Counters über die Breite des Bildes.
	add x1, x1, x16			//Der erste beschriebene Pixel ist in der zweiten Spalte der zweiten Zeile.
	mov w4, 0			//Counter = 0

.Lloop:					//Main-Loop
					//Test, ob der letzte Pixel einer Zeile erreicht wurde	
	cmp w4, w14
	b.lt .LrestLoop
	add x0, x0, 6			//Eingabebild springt um zwei Pixel weiter
	add x1, x1, 6			//Ausgabebild springt um zwei Pixel weiter
	mov w4, 0			//Counter wird zurückgesetzt
	b .Lloop
.LrestLoop:
	add w4, w4, 1			//Counter über die Breite wird inkrementiert
								
					//Berechnung des Algorithmus. w7 := A vertikal, w8 := A horizontal, 
					//w9: temp. Variable zum Laden neuer Werte, E_(x,y): Eingabebild an Stelle x,y
					//x,y: Koordinaten des momentan auszurechnenden Ausgabe-Pixels
	ldrb w9, [x0]			//w9 = E_(x-1,y-1)
	mov w7, w9
	mov w8, w9

	ldrb w9, [x0, #3]		//w9 = E_(x,y-1)
	add w7, w7, w9, lsl#1

	ldrb w9, [x0, #6]		//w9 = E_(x+1,y-1)
	add w7, w7, w9
	sub w8, w8, w9

	ldrb w9, [x0, x15]		//w9 = E_(x-1,y)
	add w8, w8, w9, lsl#1

	ldrb w9, [x0, x17]		//w9 = E_(x+1,y1)
	sub w8, w8, w9, lsl#1

	ldrb w9, [x0, x10]		//w9 = E_(x-1,y+1)
	sub w7, w7, w9
	add w8, w8, w9

	ldrb w9, [x0, x18]		//w9 = E_(x,y+1)
	sub w7, w7, w9, lsl#1

	ldrb w9, [x0, x11]		//w9 = E_(x+1,y+1)
	sub w7, w7, w9
	sub w8, w8, w9

	mul w7, w7, w7			//w7 = w7^2
	mul w8, w8, w8			//w8 = w8^2

	add w6, w8, w7
	add x0, x0, 1			//Pointer des Eingabebildes wird in dieser Schleife nicht mehr benötigt und deswegen inkrementiert

	scvtf s0, w6			//Konvertierung zu Float
	fsqrt s0, s0			//Berechnung der Wurzel
	fcvtzs w6, s0			//Konvertierung zu Integer

	mov w7, 255
	cmp w6, w7
	csel w6, w6, w7, le		//Begrenzung von w6 auf 255, Wert kann wegen der Quadrierung nicht kleiner als 0 sein

	strb w6, [x1], 1		//Wert wird gespeicht und x1 wird inkrementiert

	cmp x0, x5			//Überprüfung, ob x0 die maximale Adresse x5 erreicht hat
	b.lt .Lloop

.Lret:
	ret



.global filter_asm_ext			//x0: Input-Bild(unsigned char*), x1: Output-Bild(unsigned char*), x2: Breite b(int), x3: Höhe h(int)
filter_asm_ext:				//Methode führt das Padding für die Randpixel aus und springt danach in den Kernalgorithmus
					//Konstanten:
	add w15, w2, w2, lsl#1		//w15 = b * 3
	add w16, w15, #3		//w16 = b * 3 + 3

					//Berechnung der Startadressen für die obere und untere horizontale Spiegelung
	mul w5, w2, w3			//w5 = b * h
	add w5, w5, w5, lsl#1		//w5 = b * h * 3
	sub w5, w5, w16, lsl#1		//w5 -= 6 *(b + 1)
	add x7, x5, 6				
	add x7, x7, x0			//x7: Adresse für die obere Zeile der unteren horizontalen Spiegelung
	add x6, x0, 3			//x6: Adresse für die obere Zeile der oberen horizontalen Spiegelung

					//Berechnung der letzten Adresse der oberen horizontalen Spiegelung
	sub x8, x15, 10
	add x8, x8, x0			//Maximale Adresse für 8-byteweise Zugriffe
	add x12, x8, 13			//Maximale Adresse für byteweise Zugriffe

.LprepHorizontal:			//Spiegelung von 8 Byte pro Schleifendurchlauf
	ldr x9, [x6, x15]
	str x9, [x6], 8
	ldr x9, [x7]
	str x9, [x7, x15]
	add x7, x7, 8
	cmp x6, x8
	b.lt .LprepHorizontal

.LprepHorizontalRest:			//Spiegelung von 1 Byte pro Schleifendurchlauf für die übrigen Werte
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
	mov x6, x0			//x6: Adresse des rechten vertikalen Randpixel
	sub w7, w2, 2
	add w7, w7, w7, lsl 1		//Offset von dem ersten Pixel einer Zeile zu dem vorletztem Pixel dieser Zeile
	add w8, w7, 3			//Offset von dem ersten Pixel einer Zeile zu dem letztem Pixel dieser Zeile

	mov w13, 0			//Counter über die Höhe
.LprepVertical:
	ldrb w9, [x6, x7]		//Spiegelung des Rot-Wertes auf beiden Seiten einer Zeile
	strb w9, [x6, x8]
	ldrb w9, [x6, 3]
	strb w9, [x6], 1

	ldrb w9, [x6, x7]		//Spiegelung des Grün-Wertes auf beiden Seiten einer Zeile
	strb w9, [x6, x8]
	ldrb w9, [x6, 3]
	strb w9, [x6], 1

	ldrb w9, [x6, x7]		//Spiegelung des Blau-Wertes auf beiden Seiten einer Zeile
	strb w9, [x6, x8]
	ldrb w9, [x6, 3]
	strb w9, [x6], 1

	add x6, x6, x8			//Inkrementierung des Pointers auf das erste Byte der nächsten Zeile
	
	add w13, w13, 1
	cmp w13, w3
	b.lt .LprepVertical
	
	str x30, [sp, -16]!
	bl filter_asm			//Aufruf des Kernalgorithmus
	ldr x30, [sp], 16
	ret

