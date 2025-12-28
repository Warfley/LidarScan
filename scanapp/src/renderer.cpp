#include "renderer.h"

#include <GL/glut.h>
#include <GL/glu.h>
#include <GL/gl.h>

PointScan *current_scanner=nullptr;

std::size_t window_width=1024; 
std::size_t window_height=768;

double move_x=0;
double move_y=0;
double rot_x=0;
double rot_y=0;
double scale=0.1;

void render_cloud(void) {
    double const aspectRatio=window_width/window_height;

    glClearColor(170/255, 170/255, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glViewport(0,0,window_width,window_height);
    glFrustum(0,0,window_width,window_height, 0.01, 1000);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glTranslated(rot_x,rot_y,0);
    glScaled(scale/aspectRatio,scale,scale);
    glRotatef(rot_x,0,1,0);
    glRotatef(rot_y,1,0,0);

    glBegin(GL_POINTS);
    current_scanner->process_data<void>([](std::deque<PointScan::Slice> slices) {
        for (auto slice : slices) {
            for (auto p : slice.points) {
                glPointSize(4);
                auto pd=convert_point(p,slice.degree);
                glColor4d(1,1,1,1);
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
    glutMainLoop();
}