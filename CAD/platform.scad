use <gears.scad>

// Extra width for mount: 1mm
mount_width = 10;

module screw_mount_cylinder(h, r) {
    // TODO: Check if fit
    cylinder(h=h+mount_width, r=r+mount_width);
}

module screw_mount(h, r, socket_melt=/*Slightly smaller to melt into walls*/5) {
    difference() {
        screw_mount_cylinder(h,r);
        translate([0,0,mount_width])
            cylinder(h=h, r=r-socket_melt);
    }
}

// quarter inch screw mount
module qimount(w) {
    difference() {
        cylinder(h=70,r1=w,r2=w*0.8);
        translate([0,0,20])
        cylinder(50,r=65);
    }
}

module mount_plattform(w,screw_height,screw_distance,screw_socket_size=/*M3*/50) {
    union() {
        translate([(screw_distance/2),(screw_distance/2),-screw_height+10])
            screw_mount(screw_height,screw_socket_size);
        translate([-(screw_distance/2),(screw_distance/2),-screw_height+10])
            screw_mount(screw_height,screw_socket_size);
        translate([(screw_distance/2),-(screw_distance/2),-screw_height+10])
            screw_mount(screw_height,screw_socket_size);
        translate([-(screw_distance/2),-(screw_distance/2),-screw_height+10])
            screw_mount(screw_height,screw_socket_size);
        difference() {
            translate([0,0,-15])
                minkowski() {
                    cube([w-80,w-80,10], true);
                    cylinder(10,r=40);
                }
            translate([(screw_distance/2),(screw_distance/2),-screw_height+10])
                screw_mount_cylinder(screw_height,screw_socket_size-mount_width);
            translate([-(screw_distance/2),(screw_distance/2),-screw_height+10])
                screw_mount_cylinder(screw_height,screw_socket_size-mount_width);
            translate([(screw_distance/2),-(screw_distance/2),-screw_height+10])
                screw_mount_cylinder(screw_height,screw_socket_size-mount_width);
            translate([-(screw_distance/2),-(screw_distance/2),-screw_height+10])
                screw_mount_cylinder(screw_height,screw_socket_size-mount_width);
        }
    }
}


module servo_mount(w,screw_offset,screw_distance,screw_height,screw_socket_size=/*M2*/32) {
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
            cylinder(25, r1=w/2,r2=w*0.4);
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

union() {
    mount_plattform(750, 60, 580);
    // Screw socket for 1/4 mount
    rotate([-180,0,0])
        translate([0,0,20])
            qimount(150);
    // Mount platform for servo motor -> Directly mounted to bottom plattform
    servo_mount(w=320, screw_offset=25, screw_distance=150, screw_height=40);
    //bevel_gear(7.5, 40, 45, 40, 0, 20, 25);
}

// Zahnrad Schrittmotor: 1-2 -> 0.9°
//rotate([90,0,0])
//translate([15,100,-150])
//translate([600,0,-60])
//bevel_gear(7.5, 20, 45, 40, 50, 20, -25);
// Zahnrad schrittmotor 1-4 -> 0.45°
//rotate([-90,0,0])
//translate([0,-65,-150])
//translate([450,0,-60])
//bevel_gear(7.5, 10, 20, 30, 50, 20, -25);
