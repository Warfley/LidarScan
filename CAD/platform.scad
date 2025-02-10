use <gears.scad>

// TODO: Configure thread size
// Measured: 1mm
thread_size = 10;
// Extra width for mount: 1mm
mount_width = 10;

module screw_mount_cylinder(h, r) {
    // TODO: Check if fit
    cylinder(h=h, r=(r+thread_size)+mount_width);
}

module screw_mount(h, r) {
    difference() {
        screw_mount_cylinder(h,r+thread_size);
        translate([0,0,10])
            cylinder(h=h, r=r+thread_size);
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

module mount_plattform(w,screw_height,screw_distance,screw_size=/*M3*/30) {
    union() {
        translate([(screw_distance/2),(screw_distance/2),-screw_height+10])
            screw_mount(screw_height,screw_size);
        translate([-(screw_distance/2),(screw_distance/2),-screw_height+10])
            screw_mount(screw_height,screw_size);
        translate([(screw_distance/2),-(screw_distance/2),-screw_height+10])
            screw_mount(screw_height,screw_size);
        translate([-(screw_distance/2),-(screw_distance/2),-screw_height+10])
            screw_mount(screw_height,screw_size);
        difference() {
            translate([0,0,-15])
                minkowski() {
                    cube([w-80,w-80,10], true);
                    cylinder(10,r=40);
                }
            translate([(screw_distance/2),(screw_distance/2),-screw_height+10])
                screw_mount_cylinder(screw_height,screw_size);
            translate([-(screw_distance/2),(screw_distance/2),-screw_height+10])
                screw_mount_cylinder(screw_height,screw_size);
            translate([(screw_distance/2),-(screw_distance/2),-screw_height+10])
                screw_mount_cylinder(screw_height,screw_size);
            translate([-(screw_distance/2),-(screw_distance/2),-screw_height+10])
                screw_mount_cylinder(screw_height,screw_size);
        }
        rotate([-180,0,0])
            translate([0,0,20])
                qimount(150);
    }
}


module servo_mount(w,screw_offset,screw_distance,screw_height,screw_size=/*M2*/20) {
    union() {
        translate([(screw_distance/2),0,screw_offset])
            screw_mount(screw_height, screw_size);
        translate([-(screw_distance/2),0,screw_offset])
            screw_mount(screw_height, screw_size);
        translate([0,(screw_distance/2),screw_offset])
            screw_mount(screw_height, screw_size);
        translate([0,-(screw_distance/2),screw_offset])
            screw_mount(screw_height, screw_size);
        difference() {
            cylinder(25, r1=w/2,r2=w*0.4);
            translate([(screw_distance/2),0,screw_offset])
                screw_mount_cylinder(screw_height, screw_size);
            translate([-(screw_distance/2),0,screw_offset])
                screw_mount_cylinder(screw_height, screw_size);
            translate([0,(screw_distance/2),screw_offset])
                screw_mount_cylinder(screw_height, screw_size);
            translate([0,-(screw_distance/2),screw_offset])
                screw_mount_cylinder(screw_height, screw_size);
        }
    }
}


union() {
    mount_plattform(750, 80, 580);
    // Mount platform for servo motor -> Directly mounted to bottom plattform
    servo_mount(w=320, screw_offset=25, screw_distance=150, screw_height=60);
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
