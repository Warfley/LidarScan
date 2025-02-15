use <gears.scad>

// Extra width for mount: 1mm
mount_width = 1;
mount_offset = 1;
$fn=60;

module screw_mount_cylinder(h, d) {
    // TODO: Check if fit
    cylinder(h=h+mount_width, r=d/2 + mount_width);
}

module screw_mount(h, d, socket_melt=/*Slightly smaller to melt into walls*/0.2) {
    difference() {
        screw_mount_cylinder(h,d);
        translate([0,0,mount_width])
            cylinder(h=h, r=(d/2)-socket_melt);
    }
}

// quarter inch screw mount
module qimount(w) {
    union() {
        translate([0,0,1.3]) 
            screw_mount(12.7, 8);
        difference() {
            cylinder(h=15,r1=w,r2=w*0.50);
            translate([0,0,1.3]) 
                screw_mount_cylinder(12.7, 8-mount_width);
        }
    }
}

module mount_plattform(w,screw_height,screw_distance,screw_socket_size=/*M3*/5) {
    union() {
        translate([(screw_distance/2),(screw_distance/2),-screw_height+mount_offset])
            screw_mount(screw_height,screw_socket_size);
        translate([-(screw_distance/2),(screw_distance/2),-screw_height+mount_offset])
            screw_mount(screw_height,screw_socket_size);
        translate([(screw_distance/2),-(screw_distance/2),-screw_height+mount_offset])
            screw_mount(screw_height,screw_socket_size);
        translate([-(screw_distance/2),-(screw_distance/2),-screw_height+mount_offset])
            screw_mount(screw_height,screw_socket_size);
        difference() {
            translate([0,0,-1.5])
                minkowski() {
                    cube([w-8,w-8,1], true);
                    cylinder(1,r=4);
                }
            translate([(screw_distance/2),(screw_distance/2),-screw_height+mount_offset])
                screw_mount_cylinder(screw_height,screw_socket_size-mount_width);
            translate([-(screw_distance/2),(screw_distance/2),-screw_height+mount_offset])
                screw_mount_cylinder(screw_height,screw_socket_size-mount_width);
            translate([(screw_distance/2),-(screw_distance/2),-screw_height+mount_offset])
                screw_mount_cylinder(screw_height,screw_socket_size-mount_width);
            translate([-(screw_distance/2),-(screw_distance/2),-screw_height+mount_offset])
                screw_mount_cylinder(screw_height,screw_socket_size-mount_width);
        }
    }
}


module servo_mount(w,screw_offset,screw_distance,screw_height,screw_socket_size=/*M2*/3.2) {
    union() {
        translate([(screw_distance/2),0,screw_offset])
            screw_mount(screw_height, screw_socket_size);
        translate([-(screw_distance/2),0,screw_offset])
            screw_mount(screw_height, screw_socket_size);
        translate([0,(screw_distance/2),screw_offset])
            screw_mount(screw_height, screw_socket_size);
        translate([0,-(screw_distance/2),screw_offset])
            screw_mount(screw_height, screw_socket_size);
        difference() {
            cylinder(2.5, r1=w/2,r2=w*0.4);
            translate([(screw_distance/2),0,screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
            translate([-(screw_distance/2),0,screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
            translate([0,(screw_distance/2),screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
            translate([0,-(screw_distance/2),screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
        }
    }
}

///*
union() {
    mount_plattform(75, 6, 58);
    // Screw socket for 1/4 mount
    rotate([-180,0,0])
        translate([0,0,2])
            qimount(30);
    // Mount platform for servo motor -> Directly mounted to bottom plattform
    servo_mount(w=32, screw_offset=2.5, screw_distance=15, screw_height=4);
    //bevel_gear(0.75, 40, 45, 4, 0, 20, 25);
}
//*/

/*
// Calibration/Test mount
union() {
    // Mount platform for servo motor -> Directly mounted to bottom plattform
    servo_mount(w=32, screw_offset=2.5, screw_distance=15, screw_height=4);
    // color("black")
    translate([12,0,0]) 
    linear_extrude(2)
    polygon(points = [[0,-4],[0,4],[6,0]], paths = [[0,1,2]]);
    translate([-12,0,0]) 
    linear_extrude(2)
    polygon(points = [[0,-4],[0,4],[-6,0]], paths = [[0,1,2]]);
}
*/

// Zahnrad Schrittmotor: 1-2 -> 0.9°
//rotate([90,0,0])
//translate([1.5,10,-15])
//translate([60,0,-6])
//bevel_gear(.75, 20, 45, 4, 5, 20, -25);
// Zahnrad schrittmotor 1-4 -> 0.45°
//rotate([-90,0,0])
//translate([0,-6.5,-15])
//translate([45,0,-6])
//bevel_gear(.75, 10, 20, 3, 5, 20, -25);
