use <gears.scad>

// Extra width for mount: 1mm
mount_width = 1;
mount_offset = 1;
$fn=60;

module screw_mount_cylinder(h, d) {
    // TODO: Check if fit
    cylinder(h=h+mount_width, r=d/2 + mount_width);
}

module screw_mount(h, d) {
    difference() {
        screw_mount_cylinder(h,d);
        translate([0,0,mount_width])
            cylinder(h=h, r=d/2);
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


module servo_mount(w,h,screw_distance,screw_height,screw_socket_size=/*M2*/3.2) {
    screw_offset=h-1;
    top_widht=screw_distance/2+screw_socket_size/2+mount_width*2;
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
            cylinder(h, r1=w/2,r2=top_widht);
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

/*
// Bottom mount platform
union() {
    mount_plattform(75, 6, 58);
    // Screw socket for 1/4 mount
    rotate([-180,0,0])
        translate([0,0,2])
            qimount(30);
    // Mount platform for servo motor -> Directly mounted to bottom plattform
    servo_mount(w=32, h=4, screw_distance=15, screw_height=4);
    //bevel_gear(0.75, 40, 45, 4, 0, 20, 25);
}
*/

/*
// Calibration/Test mount
union() {
    // Mount platform for servo motor -> Directly mounted to bottom plattform
    servo_mount(w=32, h=4, screw_distance=15, screw_height=4);
    // color("black")
    translate([12,0,0])
    linear_extrude(2)
    polygon(points = [[0,-4],[0,4],[6,0]], paths = [[0,1,2]]);
    translate([-12,0,0])
    linear_extrude(2)
    polygon(points = [[0,-4],[0,4],[-6,0]], paths = [[0,1,2]]);
}
*/

module servo_frame(w,l,h,hw1,hw2,screw_position,screw_distance,screw_offset=1,screw_height=4,screw_socket_size=/*M2*/3.2) {
    union() {
        translate([l/2+screw_position,(screw_distance/2),screw_offset])
            screw_mount(screw_height, screw_socket_size);
        translate([l/2+screw_position,-(screw_distance/2),screw_offset])
            screw_mount(screw_height, screw_socket_size);
        translate([-l/2-screw_position,(screw_distance/2),screw_offset])
            screw_mount(screw_height, screw_socket_size);
        translate([-l/2-screw_position,-(screw_distance/2),screw_offset])
            screw_mount(screw_height, screw_socket_size);
        difference() {
            translate([0,0,(h-1-screw_offset)/2-1])
                // unline the other plattform, be at least as thick as screws to ensure it prints a good floor
                minkowski() {
                    cube([l*1.25,w,h-1-screw_offset+2],center=true);
                    cylinder(1,r=4);
                }
            translate([-14,0,0])
                cylinder(h=h-screw_offset,r1=hw1,r2=hw2);
            translate([-14,0,-2])
                cylinder(h=2,r=hw1);
            translate([0,0,h/2-screw_offset])
                cube([l,w+8,h],center=true);
            translate([l/2+screw_position,(screw_distance/2),screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
            translate([l/2+screw_position,-(screw_distance/2),screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
            translate([-l/2-screw_position,(screw_distance/2),screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
            translate([-l/2-screw_position,-(screw_distance/2),screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
        }
    }
}

// Top platform for servo and lidar
union() {
    difference() {
        // Upside down to screw on top
        rotate([180,0,0])
        translate([0,0,2])
            mount_plattform(75, 6, 58);
        translate([0,0,-3])
        cylinder(3, r=10);
    }
    translate([14,0,0])
    servo_frame(w=20, l=40, h=6, hw1=10,hw2=6, screw_position=5, screw_distance=10);
}

//translate([30,0,0])
//   screw_mount(6,5);
//translate([-30,0,0])
//screw_mount(12.7,8);

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
