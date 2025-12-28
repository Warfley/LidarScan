#include "renderer.h"

#include <GL/glut.h>
#include <GL/glu.h>
#include <GL/gl.h>

PointScan *current_scanner=nullptr;

std::size_t window_width=1024; 
std::size_t window_height=768;

void on_resize(int w, int h) {
    window_height=h;
    window_width=w;
}

void on_key(unsigned char k, int x, int y) {
    static bool fullscreen = false;
    if (fullscreen) {
        glutReshapeWindow(1024, 768);
    } else {
        glutFullScreen();
    }
    fullscreen=!fullscreen;
}

Vec4D point_color(double h) {
    if (h>1) {
        h=1;
    }
    constexpr auto v = 1.0;
    constexpr auto s = 1.0;

	
	int i = floor(h * 6);
	double f = h * 6 - i;
	double p = v * (1 - s);
	double q = v * (1 - f * s);
	double t = v * (1 - (1 - f) * s);

	switch (i % 6) {
		case 0: return Vec4D{.x=v,.y=t,.z=p,.a=1};
		case 1: return Vec4D{.x=q,.y=v,.z=p,.a=1};
		case 2: return Vec4D{.x=p,.y=v,.z=t,.a=1};
		case 3: return Vec4D{.x=p,.y=q,.z=v,.a=1};
		case 4: return Vec4D{.x=t,.y=p,.z=v,.a=1};
		case 5: return Vec4D{.x=v,.y=p,.z=q,.a=1};
	}
    return Vec4D{.x=0,.y=0,.z=0,.a=1};
}

double move_x=0;
double move_y=-1.15;
double rot_x=0;
double rot_y=75;
double rot_z=0;
double scale=0.1;

void render_cloud(void) {
    static auto last_frame=std::chrono::high_resolution_clock::now();
    auto delta = std::chrono::high_resolution_clock::now()-last_frame;
    auto wobble = std::sin(static_cast<double>(delta.count())/100000000000);
    auto wobble2 = std::cos(static_cast<double>(delta.count())/600000000000);
    double const aspectRatio=static_cast<double>(window_width)/window_height;

    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glViewport(0,0,window_width,window_height);
    glFrustum(0,0,window_width,window_height, 0.01, 1000);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glTranslated(move_x,move_y,0);
    glScaled(scale/aspectRatio,scale,scale);
    glRotatef(rot_z+wobble2*10,1,0,0);
    glRotatef(rot_y+wobble*15,1,0,0);
    glRotatef(rot_x,0,1,0);

    glBegin(GL_POINTS);
    current_scanner->process_data<void>([](std::deque<PointScan::Slice> slices) {
        auto now=std::chrono::high_resolution_clock::now();
        for (auto slice : slices) {
            auto timediff=now-slice.time;
            auto share = timediff.count()/static_cast<double>(current_scanner->scan_time().count());
            auto color=point_color(share);
            for (auto p : slice.points) {
                if (current_scanner->filter_point(p)) {
                    continue;
                }
                glPointSize(4);
                auto pd=convert_point(p,slice.degree);
                glColor4d(color.x,color.y,color.z,color.a);
                glVertex3d(pd.x,pd.y,pd.z);
            }
        }
    });
    glEnd();
    glutSwapBuffers();
    glutPostRedisplay();
}

void start_renderer(PointScan *scan, int argc, char ** argv) {
    current_scanner=scan;
    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA | GLUT_DEPTH);

    glutInitWindowSize(window_width,window_height);
    glutInitWindowPosition(100, 100);
    glutCreateWindow("Preview");
    glutDisplayFunc(render_cloud);
    glutReshapeFunc(on_resize);
    glutKeyboardFunc(on_key);
    glutMainLoop();
}