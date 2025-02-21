# LIDAR based 3D Room Scanner

## Prequesites
Besides the specific components used to build this project, the following Hardware and Software is required:

1. 3D Printer: I used the Anycubic Kobra 3
2. Soldering Iron
3. Basic Tooling (screw drivers, ruler, level, etc)
4. Linux (I didn't bother trying to build this for windows) with the following software:
    * [OpenSCAD](https://openscad.org/)
    * [ESP-IDF](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/get-started/linux-macos-setup.html)
    * C++ Tooling (Clang, Make, etc.)
5. Consumables (Filament, lubrication oil)

### Components
The following components where used for the project. Added (non affiliate) links to Amazon, and prices, but the same components can be bough cheaper on other platforms as well:
1. [SlamTec RPLidar A1](https://www.amazon.de/dp/B07VLFGT27) (70€)
2. [ESP32 Development Board](https://www.amazon.de/dp/B0DGG7LXMF) (8€)
3. [M996R Servo](https://www.amazon.de/dp/B07H87592P) (32€): Technically only one is required, but quality varies a lot, so you may need to test out a few to find one that works well enough
4. [8 times M2x6, 4 times M2.5x8, 12 times M3x8 screws](https://www.amazon.de/dp/B0DBTNWDJB) (5€)
5. [2 times M5x16 6x M5x12 screws](https://www.amazon.de/dp/B0D258MS9F) (15€)
6. 8 times M3 nuts (included above)
7. [4 times M2x4 and 4 M2x3, 6 times M5x6, 2 times M5x10 and 1 quarter inch thread insert](https://www.amazon.de/dp/B0D1VKC5K9) (15€)
8. [Ball bearing turning table](https://www.amazon.de/dp/B0B3X7R961) (8€)
9. [Camera Tripod](https://www.amazon.de/dp/B0B8YHTWGY) (33€)

The total cost for me therefore was around 185€ as an initial cost. But with most of the screws and threads being more than you need for one project, and ESP32 and M996 being quite expensive on Amazon, the whole project can probably be done with a budget of around 120€.

## Building
To build the Project first the hardware needs to be printed and assembled.

### 3D Printing

The [platform.scad](CAD/platform.scad) contains the CAD files for all the 3D printable parts, but as a single file and arranged in position of assembly.
The file contains 6 different objects:
1. Tripod Mount
2. Bottom platform
3. Top Platform
4. Lidar Mount
5. 2 Beams for fixating the Lidar mount further

To print these parts, you need to isolate each part (by setting all other part visibilities to false in the beginning of the scad file), rendering that part and exporting it to STL.

All parts are designed that, when oriented correctly, they can be printed without supports.

My colorized print takes around 6 hours for a full print of all parts, on two different plates, and consumes roughly 110g of PLA filament.

### Assembling the Print

After printing, the thread inserts need to be melted into the 3D prints using a soldering iron.

#### Tripod Mount
On the bottom you need to melt in the quarter inch thread insert, and on the top 4 M3x4 threads on which the bottom platform will be screwd onto.

#### Bottom Platform
The bottom platform has in the middle the mount point for the servo. Here you need to insert 4 M2x4 threads.

Afterwards you can screw the platform onto the tripod mount using 4 M3x6 screws.
Once the Tripod Mount is attached to the bottom platform, screw it onto the turning table using 4 M3x6 screws and fixate using nuts.

Add 4 M3x6 screws to the top of the turning table, and fixate with nuts. The nuts will serve as padding between the turning table and the top platform, which wil be put on to p of the M3 screws.

#### Lidar Mount
Add the 2 M5x10 thread inserts at the bottom. Afterwards screw the M2.5x8 screws in the holes on the back. Note the holes are designed that the head of the screw can be inserted deep into the print.

Fixate the RPLidar A1 using the M2.5 screws.

#### Beams
Add the 6 M5x6 inserts into the ends of the beams. Screw the smaller beam to the top of the larger one using M5x12 screws.
The feet point inwards on both beams.

#### Top Patform
The top platform has 4 inlets for mounting the servo onto. Add 4 M2x3 thread inserts in the yellow tubes.

Afterwards screw the Lidard mount very tightly using 2 M5x16 screws onto the top platform, as well as the long beam using 2 M5x12 screws and the end of the short beam to the top of the Lidar mount using the last 2 M5x2 screws.

Note the top beam adds an obstacle for the scan. As it is on top where usually only the roof of the room is, this is usually not an issue. But if you want a clear scan of the top of the lidar, you can also remove the beam but this may result in some shakier measurements when the lidar is running.

After assembling the platform and lidar mount, put it on top of the turning table, using the already prepared screws and fixate using nuts.

Do not yet add the servo, as it needs to be set to the 0 position first.

#### Tripod
Once you assembled all the parts as described above, you can simply mount it on the tripod using the quarter inch screw insert on the bottom.
